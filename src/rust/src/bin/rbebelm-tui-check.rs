#[cfg(not(unix))]
fn main() -> anyhow::Result<()> {
    anyhow::bail!("rbebelm-tui-check currently requires a Unix pseudo-terminal")
}

#[cfg(unix)]
mod unix_check {
    use std::ffi::{CStr, CString};
    use std::fs::{self, File};
    use std::io::{BufRead, BufReader, Read};
    use std::os::fd::{AsRawFd, FromRawFd, OwnedFd, RawFd};
    use std::path::{Path, PathBuf};
    use std::process::{Child, Command, Stdio};
    use std::sync::mpsc;
    use std::thread;
    use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

    use anyhow::{anyhow, bail, Context, Result};
    use serde_json::Value;

    const R_SERVER: &str = r#"
suppressPackageStartupMessages(library(Rbebelm))
if (!requireNamespace("nanonext", quietly = TRUE)) stop("nanonext is required for the TUI check server")
if (!requireNamespace("later", quietly = TRUE)) stop("later is required to drive the TUI check server event loop")

url <- Sys.getenv("RBEBELM_TUI_SMOKE_URL", "http://127.0.0.1:18767")
plot_cwd <- Sys.getenv("RBEBELM_TUI_SMOKE_PLOT_CWD", tempdir())
dir.create(plot_cwd, recursive = TRUE, showWarnings = FALSE)

CheckAgentS3 <- S7::new_S3_class("rbebelmTuiCheckAgent")
S7::method(bebel_backend_append_user, CheckAgentS3) <- function(agent, message) {
  agent$transcript <- c(agent$transcript, paste("user:", message))
  agent
}
S7::method(bebel_backend_append_system, CheckAgentS3) <- function(agent, message, tools = NULL) {
  agent$transcript <- c(agent$transcript, paste("system:", message))
  agent
}
S7::method(bebel_backend_append_tool_result, CheckAgentS3) <- function(agent, content) {
  agent$transcript <- c(agent$transcript, paste("tool:", content))
  agent
}
S7::method(bebel_backend_assistant_turn, CheckAgentS3) <- function(agent, on_event = NULL, check_interrupt = TRUE, stop_on_tool_call = FALSE) {
  if (is.function(on_event)) {
    on_event(list(type = "text_start"))
    on_event(list(type = "text_delta", delta = "check assistant"))
    on_event(list(type = "done"))
  }
  list(text = "check assistant", stop = "eos", prompt_tokens = 0L, generated_tokens = 2L, prefill_seconds = 0, decode_seconds = 0)
}
S7::method(bebel_backend_info, CheckAgentS3) <- function(agent) {
  list(provider = "rbebelm-check", model = "fake-loop", backend = "fake")
}
S7::method(bebel_backend_transcript, CheckAgentS3) <- function(agent) paste(agent$transcript, collapse = "\n")
S7::method(bebel_backend_clear, CheckAgentS3) <- function(agent) {
  agent$transcript <- character()
  agent
}

agent <- structure(new.env(parent = emptyenv()), class = "rbebelmTuiCheckAgent")
agent$transcript <- character()
plot_env <- new.env(parent = globalenv())
plot_env$x <- 1:10

old_device <- getOption("Rbebelm.graphics.device", NULL)
options(Rbebelm.graphics.device = "png")
on.exit({
  if (is.null(old_device)) options(Rbebelm.graphics.device = NULL) else options(Rbebelm.graphics.device = old_device)
}, add = TRUE)

rplot <- bebel_loop_command(
  "rplot",
  function(args, loop, context) {
    code <- trimws(args)
    if (!nzchar(code)) code <- "plot(x, x^2, type = 'b', main = 'TUI check plot')"
    exprs <- parse(text = code, srcfile = NULL)
    Rbebelm:::bebel_graphics_render_plot(exprs, plot_env, cwd = plot_cwd, width = 480L, height = 320L, device = "png")
  },
  description = "Render an R plot for TUI checking.",
  usage = "/rplot [plot-code]"
)

loop <- bebel_agent_loop(
  agent,
  tools = list(),
  extensions = list(bebel_extension("tui_check_graphics", commands = list(rplot = rplot))),
  session = FALSE
)
server <- bebel_loop_rpc_server(loop, url = url)
if (is.function(server$start)) server$start()
on.exit(if (is.function(server$close)) try(server$close(), silent = TRUE), add = TRUE)

cat(sprintf('{"ready":true,"url":"%s","pid":%d,"plot_cwd":"%s"}\n', url, Sys.getpid(), normalizePath(plot_cwd, winslash = "/", mustWork = FALSE)))
flush.console()
repeat {
  later::run_now(0.05)
  Sys.sleep(0.01)
}
"#;

    #[derive(Debug)]
    struct Args {
        tui: Option<String>,
        rscript: String,
        timeout: Duration,
        keep_artifacts: bool,
        rows: u16,
        cols: u16,
    }

    impl Default for Args {
        fn default() -> Self {
            Self {
                tui: None,
                rscript: std::env::var("RSCRIPT").unwrap_or_else(|_| "Rscript".to_string()),
                timeout: Duration::from_secs(30),
                keep_artifacts: false,
                rows: 48,
                cols: 140,
            }
        }
    }

    pub fn main() -> Result<()> {
        let args = parse_args()?;
        let tmp = SmokeTempDir::new(args.keep_artifacts)?;
        let tui = find_tui(&args)?;
        let port = free_port()?;
        let url = format!("http://127.0.0.1:{port}");
        let mut server = start_r_server(&args.rscript, tmp.path(), &url)?;
        let result = (|| -> Result<()> {
            let endpoint = server.ready_url.clone();
            drive_tui(&tui, &endpoint, args.rows, args.cols, args.timeout, tmp.path())?;
            let pngs = find_pngs(&tmp.path().join("plots").join("rbebelm-plots"))?;
            if pngs.is_empty() {
                bail!("/rplot completed in the TUI but no PNG artifact was written");
            }
            for png in &pngs {
                if fs::metadata(png).map(|m| m.len()).unwrap_or(0) == 0 {
                    bail!("PNG artifact exists but is empty: {}", png.display());
                }
            }
            println!("TUI graphics check OK");
            println!("  tui: {}", tui.display());
            println!("  endpoint: {}", endpoint);
            if args.keep_artifacts {
                println!("  png: {}", pngs.last().unwrap().display());
                println!("  terminal log: {}", tmp.path().join("tui-terminal.log").display());
            } else {
                println!("  png: verified and cleaned up; rerun with --keep-artifacts to inspect it");
                println!("  terminal log: verified and cleaned up; rerun with --keep-artifacts to inspect it");
            }
            Ok(())
        })();
        stop_child(&mut server.child);
        result
    }

    fn parse_args() -> Result<Args> {
        let mut args = Args::default();
        let mut it = std::env::args().skip(1);
        while let Some(arg) = it.next() {
            match arg.as_str() {
                "--tui" => args.tui = Some(next_arg(&mut it, "--tui")?),
                "--rscript" => args.rscript = next_arg(&mut it, "--rscript")?,
                "--timeout" => {
                    let value: f64 = next_arg(&mut it, "--timeout")?.parse().context("--timeout must be a number")?;
                    args.timeout = Duration::from_secs_f64(value.max(0.1));
                }
                "--keep-artifacts" => args.keep_artifacts = true,
                "--rows" => args.rows = next_arg(&mut it, "--rows")?.parse().context("--rows must be an integer")?,
                "--cols" => args.cols = next_arg(&mut it, "--cols")?.parse().context("--cols must be an integer")?,
                "-h" | "--help" => {
                    println!("Usage: rbebelm-tui-check [--tui PATH] [--rscript Rscript] [--timeout SECONDS] [--keep-artifacts] [--rows N] [--cols N]");
                    std::process::exit(0);
                }
                other => bail!("unknown argument: {other}"),
            }
        }
        Ok(args)
    }

    fn next_arg(it: &mut impl Iterator<Item = String>, flag: &str) -> Result<String> {
        it.next().ok_or_else(|| anyhow!("{flag} requires a value"))
    }

    struct SmokeTempDir {
        path: PathBuf,
        keep: bool,
    }

    impl SmokeTempDir {
        fn new(keep: bool) -> Result<Self> {
            let stamp = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_nanos();
            let path = std::env::temp_dir().join(format!("rbebelm-tui-check-{}-{stamp}", std::process::id()));
            fs::create_dir_all(&path).with_context(|| format!("failed to create {}", path.display()))?;
            Ok(Self { path, keep })
        }

        fn path(&self) -> &Path {
            &self.path
        }
    }

    impl Drop for SmokeTempDir {
        fn drop(&mut self) {
            if self.keep {
                eprintln!("kept artifacts: {}", self.path.display());
            } else {
                let _ = fs::remove_dir_all(&self.path);
            }
        }
    }

    fn free_port() -> Result<u16> {
        let listener = std::net::TcpListener::bind(("127.0.0.1", 0)).context("failed to allocate localhost port")?;
        Ok(listener.local_addr()?.port())
    }

    fn run_stdout(command: &str, args: &[&str]) -> Result<String> {
        let output = Command::new(command)
            .args(args)
            .output()
            .with_context(|| format!("failed to run {command}"))?;
        if !output.status.success() {
            bail!(
                "command failed ({}): {} {}\n{}",
                output.status,
                command,
                args.join(" "),
                String::from_utf8_lossy(&output.stderr)
            );
        }
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }

    fn find_tui(args: &Args) -> Result<PathBuf> {
        let mut candidates = Vec::new();
        candidates.extend(args.tui.as_ref().map(PathBuf::from));
        candidates.extend(std::env::var_os("RBEBELM_TUI_BIN").map(PathBuf::from));
        if let Ok(path) = run_stdout(&args.rscript, &["--vanilla", "-e", "cat(system.file('bin/rbebelm-tui', package='Rbebelm'))"]) {
            let path = path.trim();
            if !path.is_empty() {
                candidates.push(PathBuf::from(path));
            }
        }
        candidates.push(PathBuf::from("inst/bin/rbebelm-tui"));
        for candidate in candidates {
            if candidate.is_file() {
                return Ok(candidate.canonicalize().unwrap_or(candidate));
            }
        }
        bail!("could not find rbebelm-tui; run `make dev-install`, set RBEBELM_TUI_BIN, or pass --tui")
    }

    struct RServer {
        child: Child,
        ready_url: String,
    }

    fn start_r_server(rscript: &str, tmp: &Path, url: &str) -> Result<RServer> {
        let server_file = tmp.join("tui-check-server.R");
        fs::write(&server_file, R_SERVER).with_context(|| format!("failed to write {}", server_file.display()))?;
        let mut child = Command::new(rscript)
            .arg("--vanilla")
            .arg(&server_file)
            .env("RBEBELM_TUI_SMOKE_URL", url)
            .env("RBEBELM_TUI_SMOKE_PLOT_CWD", tmp.join("plots"))
            .env("RBEBELM_GRAPHICS_DEVICE", "png")
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .with_context(|| format!("failed to start {rscript}"))?;

        let stdout = child.stdout.take().ok_or_else(|| anyhow!("R server stdout was not piped"))?;
        let (tx, rx) = mpsc::channel();
        thread::spawn(move || {
            for line in BufReader::new(stdout).lines() {
                if tx.send(line).is_err() {
                    break;
                }
            }
        });

        let deadline = Instant::now() + Duration::from_secs(20);
        while Instant::now() < deadline {
            if let Some(status) = child.try_wait().context("failed to poll R check server")? {
                let mut stderr = String::new();
                if let Some(mut err) = child.stderr.take() {
                    let _ = err.read_to_string(&mut stderr);
                }
                bail!("R check server exited early with status {status}\n{stderr}");
            }
            match rx.recv_timeout(Duration::from_millis(100)) {
                Ok(Ok(line)) => {
                    if let Ok(value) = serde_json::from_str::<Value>(&line) {
                        if value.get("ready").and_then(Value::as_bool) == Some(true) {
                            let ready_url = value.get("url").and_then(Value::as_str).unwrap_or(url).to_string();
                            return Ok(RServer { child, ready_url });
                        }
                    }
                }
                Ok(Err(err)) => bail!("failed to read R check server stdout: {err}"),
                Err(mpsc::RecvTimeoutError::Timeout) => {}
                Err(mpsc::RecvTimeoutError::Disconnected) => bail!("R check server stdout closed before readiness"),
            }
        }
        stop_child(&mut child);
        bail!("timed out waiting for R check server readiness")
    }

    fn stop_child(child: &mut Child) {
        if child.try_wait().ok().flatten().is_some() {
            return;
        }
        let _ = child.kill();
        let _ = child.wait();
    }

    fn open_pty(rows: u16, cols: u16) -> Result<(OwnedFd, OwnedFd)> {
        unsafe {
            let master = libc::posix_openpt(libc::O_RDWR | libc::O_NOCTTY);
            if master < 0 {
                return Err(std::io::Error::last_os_error()).context("posix_openpt failed");
            }
            let master = OwnedFd::from_raw_fd(master);
            if libc::grantpt(master.as_raw_fd()) != 0 {
                return Err(std::io::Error::last_os_error()).context("grantpt failed");
            }
            if libc::unlockpt(master.as_raw_fd()) != 0 {
                return Err(std::io::Error::last_os_error()).context("unlockpt failed");
            }
            let mut name = vec![0_i8; 256];
            if libc::ptsname_r(master.as_raw_fd(), name.as_mut_ptr(), name.len()) != 0 {
                return Err(std::io::Error::last_os_error()).context("ptsname_r failed");
            }
            let path = CStr::from_ptr(name.as_ptr()).to_owned();
            let slave_fd = libc::open(path.as_ptr(), libc::O_RDWR | libc::O_NOCTTY);
            if slave_fd < 0 {
                return Err(std::io::Error::last_os_error()).context("failed to open PTY slave");
            }
            let slave = OwnedFd::from_raw_fd(slave_fd);
            set_winsize(slave.as_raw_fd(), rows, cols).ok();
            set_nonblocking(master.as_raw_fd())?;
            Ok((master, slave))
        }
    }

    fn set_winsize(fd: RawFd, rows: u16, cols: u16) -> Result<()> {
        let winsize = libc::winsize { ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0 };
        let rc = unsafe { libc::ioctl(fd, libc::TIOCSWINSZ, &winsize) };
        if rc == 0 { Ok(()) } else { Err(std::io::Error::last_os_error()).context("TIOCSWINSZ failed") }
    }

    fn set_nonblocking(fd: RawFd) -> Result<()> {
        unsafe {
            let flags = libc::fcntl(fd, libc::F_GETFL);
            if flags < 0 {
                return Err(std::io::Error::last_os_error()).context("fcntl(F_GETFL) failed");
            }
            if libc::fcntl(fd, libc::F_SETFL, flags | libc::O_NONBLOCK) < 0 {
                return Err(std::io::Error::last_os_error()).context("fcntl(F_SETFL) failed");
            }
        }
        Ok(())
    }

    fn dup_file(fd: RawFd) -> Result<File> {
        let duped = unsafe { libc::dup(fd) };
        if duped < 0 {
            return Err(std::io::Error::last_os_error()).context("dup failed");
        }
        Ok(unsafe { File::from_raw_fd(duped) })
    }

    fn drive_tui(tui: &Path, url: &str, rows: u16, cols: u16, timeout: Duration, tmp: &Path) -> Result<()> {
        let (master, slave) = open_pty(rows, cols)?;
        let slave_fd = slave.as_raw_fd();
        let stdin = dup_file(slave_fd)?;
        let stdout = dup_file(slave_fd)?;
        let stderr = dup_file(slave_fd)?;
        let mut child = Command::new(tui)
            .args(["chat", "--url", url, "--max-steps", "1"])
            .env("TERM", std::env::var("TERM").unwrap_or_else(|_| "xterm-256color".to_string()))
            .env("COLORTERM", std::env::var("COLORTERM").unwrap_or_else(|_| "truecolor".to_string()))
            .stdin(Stdio::from(stdin))
            .stdout(Stdio::from(stdout))
            .stderr(Stdio::from(stderr))
            .spawn()
            .with_context(|| format!("failed to start {}", tui.display()))?;
        drop(slave);

        thread::sleep(Duration::from_millis(750));
        write_fd(master.as_raw_fd(), b"/rplot plot(x, x^2, type = 'b', main = 'TUI check plot')\r")?;
        let data = read_until_tokens(
            master.as_raw_fd(),
            &mut child,
            &["image/png", "thumbnail:", "Preview: braille"],
            timeout,
        )?;
        fs::write(tmp.join("tui-terminal.log"), &data).context("failed to write terminal log")?;
        let _ = write_fd(master.as_raw_fd(), b"/quit\r");
        wait_or_kill(&mut child, Duration::from_secs(5));
        Ok(())
    }

    fn write_fd(fd: RawFd, mut bytes: &[u8]) -> Result<()> {
        while !bytes.is_empty() {
            let n = unsafe { libc::write(fd, bytes.as_ptr().cast(), bytes.len()) };
            if n < 0 {
                let err = std::io::Error::last_os_error();
                if err.kind() == std::io::ErrorKind::Interrupted || err.kind() == std::io::ErrorKind::WouldBlock {
                    thread::sleep(Duration::from_millis(10));
                    continue;
                }
                return Err(err).context("failed to write PTY");
            }
            bytes = &bytes[n as usize..];
        }
        Ok(())
    }

    fn read_until_tokens(fd: RawFd, child: &mut Child, tokens: &[&str], timeout: Duration) -> Result<Vec<u8>> {
        let mut data = Vec::new();
        let deadline = Instant::now() + timeout;
        while Instant::now() < deadline {
            if let Some(status) = child.try_wait().context("failed to poll TUI")? {
                bail!("TUI exited early with status {status}\n{}", String::from_utf8_lossy(&data));
            }
            let mut pollfd = libc::pollfd { fd, events: libc::POLLIN, revents: 0 };
            let rc = unsafe { libc::poll(&mut pollfd, 1, 50) };
            if rc < 0 {
                let err = std::io::Error::last_os_error();
                if err.kind() == std::io::ErrorKind::Interrupted {
                    continue;
                }
                return Err(err).context("poll failed");
            }
            if rc == 0 || (pollfd.revents & libc::POLLIN) == 0 {
                continue;
            }
            let mut buf = [0_u8; 65536];
            loop {
                let n = unsafe { libc::read(fd, buf.as_mut_ptr().cast(), buf.len()) };
                if n > 0 {
                    data.extend_from_slice(&buf[..n as usize]);
                    let text = String::from_utf8_lossy(&data);
                    if tokens.iter().all(|token| text.contains(token)) {
                        return Ok(data);
                    }
                    continue;
                }
                if n == 0 {
                    break;
                }
                let err = std::io::Error::last_os_error();
                if err.kind() == std::io::ErrorKind::Interrupted {
                    continue;
                }
                if err.kind() == std::io::ErrorKind::WouldBlock {
                    break;
                }
                return Err(err).context("failed to read PTY");
            }
        }
        let text = String::from_utf8_lossy(&data);
        let missing = tokens.iter().filter(|token| !text.contains(**token)).copied().collect::<Vec<_>>().join(", ");
        bail!("timed out waiting for terminal tokens: {missing}\n{}", text.chars().rev().take(4000).collect::<String>().chars().rev().collect::<String>())
    }

    fn wait_or_kill(child: &mut Child, timeout: Duration) {
        let deadline = Instant::now() + timeout;
        while Instant::now() < deadline {
            if child.try_wait().ok().flatten().is_some() {
                return;
            }
            thread::sleep(Duration::from_millis(50));
        }
        stop_child(child);
    }

    fn find_pngs(dir: &Path) -> Result<Vec<PathBuf>> {
        let mut out = Vec::new();
        if dir.is_dir() {
            for entry in fs::read_dir(dir).with_context(|| format!("failed to read {}", dir.display()))? {
                let path = entry?.path();
                if path.extension().and_then(|x| x.to_str()) == Some("png") {
                    out.push(path);
                }
            }
        }
        out.sort();
        Ok(out)
    }

    #[allow(dead_code)]
    fn cstring(s: &str) -> Result<CString> {
        CString::new(s).context("string contained NUL")
    }
}

#[cfg(unix)]
fn main() -> anyhow::Result<()> {
    unix_check::main()
}
