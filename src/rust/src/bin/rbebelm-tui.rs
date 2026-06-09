use std::fs;
use std::io::{self, BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::{Duration, Instant};

use anyhow::{anyhow, Context, Result};
use clap::{Args, Parser, Subcommand};
use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyModifiers};
use crossterm::execute;
use crossterm::terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen};
use ratatui::backend::CrosstermBackend;
use ratatui::layout::{Constraint, Direction, Layout};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Paragraph, Wrap};
use ratatui::Terminal;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

#[derive(Parser, Debug)]
#[command(name = "rbebelm-tui")]
#[command(about = "ARF-style terminal frontend and transport client for Rbebelm agent loops")]
#[command(after_help = "Examples:\n  rbebelm-tui run --weights /path/to/model.gguf\n  BEBELM_WEIGHTS_FILE=/path/to/model.gguf rbebelm-tui\n  rbebelm-tui command --type catalog --params '{}'\n  rbebelm-tui stream --url http://127.0.0.1:8080")]
struct Cli {
    /// Path to a TOML configuration file.
    #[arg(long, global = true, env = "RBEBELM_TUI_CONFIG")]
    config: Option<PathBuf>,

    #[command(subcommand)]
    command: Option<CommandKind>,
}

#[derive(Subcommand, Debug)]
enum CommandKind {
    /// Start a local R host, attach chat, and stop the host on exit.
    Run(RunArgs),
    /// Manage the TUI TOML configuration.
    Config(ConfigCommand),
    /// Start only the Rbebelm loop host in an R process.
    Headless(HeadlessArgs),
    /// Call one JSON-RPC method on a running Rbebelm loop host (compatibility control plane).
    Rpc(RpcArgs),
    /// Send one typed JSON command to a running Rbebelm loop host.
    Command(CommandArgs),
    /// Print the NDJSON event stream from a running Rbebelm loop host.
    Stream(StreamArgs),
    /// Attach a minimal crossterm/ratatui chat frontend to a loop event stream.
    Chat(ChatArgs),
}

#[derive(Args, Debug)]
struct ConfigCommand {
    #[command(subcommand)]
    command: ConfigSubcommand,
}

#[derive(Subcommand, Debug)]
enum ConfigSubcommand {
    /// Print the resolved config path.
    Path,
    /// Write a default config file.
    Init {
        /// Overwrite an existing config file.
        #[arg(long)]
        force: bool,
    },
    /// Print the default config TOML.
    Default,
}

#[derive(Args, Debug, Default)]
struct RunArgs {
    /// GGUF weights path. Falls back to config, then BEBELM_WEIGHTS_FILE.
    #[arg(long, env = "BEBELM_WEIGHTS_FILE")]
    weights: Option<String>,
    /// HTTP(S) URL for the Rbebelm loop endpoint.
    #[arg(long)]
    url: Option<String>,
    /// Rscript executable.
    #[arg(long)]
    rscript: Option<String>,
    /// Number of model threads.
    #[arg(long)]
    num_threads: Option<u32>,
    /// Maximum generated tokens per assistant turn.
    #[arg(long)]
    max_gen: Option<u32>,
    /// Maximum thinking tokens per assistant turn.
    #[arg(long)]
    max_think: Option<u32>,
    /// Maximum assistant/tool loop steps per prompt.
    #[arg(long)]
    max_steps: Option<u32>,
    /// Expose R evaluation tools to the model.
    #[arg(long)]
    allow_eval: bool,
    /// Disable model-side R evaluation/plot tools.
    #[arg(long)]
    no_eval: bool,
    /// Use sampling instead of greedy decoding.
    #[arg(long)]
    sample: bool,
}

#[derive(Args, Debug)]
struct HeadlessArgs {
    /// GGUF weights path. Falls back to config, then BEBELM_WEIGHTS_FILE.
    #[arg(long, env = "BEBELM_WEIGHTS_FILE")]
    weights: Option<String>,
    /// HTTP(S) URL for the Rbebelm loop endpoint.
    #[arg(long)]
    url: Option<String>,
    /// Rscript executable.
    #[arg(long)]
    rscript: Option<String>,
    /// Number of model threads.
    #[arg(long)]
    num_threads: Option<u32>,
    /// Maximum generated tokens per assistant turn.
    #[arg(long)]
    max_gen: Option<u32>,
    /// Maximum thinking tokens per assistant turn.
    #[arg(long)]
    max_think: Option<u32>,
    /// Maximum assistant/tool loop steps per prompt.
    #[arg(long)]
    max_steps: Option<u32>,
    /// Expose R evaluation tools to the model.
    #[arg(long)]
    allow_eval: bool,
    /// Disable model-side R evaluation/plot tools.
    #[arg(long)]
    no_eval: bool,
    /// Use sampling instead of greedy decoding.
    #[arg(long)]
    sample: bool,
    /// Print readiness as JSON.
    #[arg(long)]
    json: bool,
}

impl From<RunArgs> for HeadlessArgs {
    fn from(args: RunArgs) -> Self {
        Self {
            weights: args.weights,
            url: args.url,
            rscript: args.rscript,
            num_threads: args.num_threads,
            max_gen: args.max_gen,
            max_think: args.max_think,
            max_steps: args.max_steps,
            allow_eval: args.allow_eval,
            no_eval: args.no_eval,
            sample: args.sample,
            json: false,
        }
    }
}

impl Default for HeadlessArgs {
    fn default() -> Self {
        Self {
            weights: None,
            url: None,
            rscript: None,
            num_threads: None,
            max_gen: None,
            max_think: None,
            max_steps: None,
            allow_eval: false,
            no_eval: false,
            sample: false,
            json: false,
        }
    }
}

#[derive(Debug, Clone)]
struct HeadlessConfig {
    weights: String,
    url: String,
    rscript: String,
    num_threads: u32,
    max_gen: u32,
    max_think: u32,
    max_steps: u32,
    allow_eval: bool,
    greedy: bool,
    json: bool,
}

#[derive(Args, Debug)]
struct RpcArgs {
    /// Rbebelm loop endpoint base URL.
    #[arg(long)]
    url: Option<String>,
    /// JSON-RPC method name, e.g. session/info, tools/list, turn.
    #[arg(long)]
    method: String,
    /// JSON object parameters.
    #[arg(long, default_value = "{}")]
    params: String,
}

#[derive(Args, Debug)]
struct CommandArgs {
    /// Rbebelm loop host base URL.
    #[arg(long)]
    url: Option<String>,
    /// Command type, e.g. session_info, tools_list, turn, steer, followUp.
    #[arg(long)]
    r#type: String,
    /// JSON object fields merged into the command.
    #[arg(long, default_value = "{}")]
    params: String,
}

#[derive(Args, Debug)]
struct StreamArgs {
    /// Rbebelm loop host base URL.
    #[arg(long)]
    url: Option<String>,
    /// Replay events after this sequence number.
    #[arg(long, default_value_t = 0)]
    since: u64,
}

#[derive(Args, Debug)]
struct ChatArgs {
    /// Rbebelm loop host base URL.
    #[arg(long)]
    url: Option<String>,
    /// Maximum assistant/tool loop steps per prompt.
    #[arg(long)]
    max_steps: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Config {
    startup: StartupConfig,
    tui: TuiConfig,
    keybindings: KeybindingConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct StartupConfig {
    rscript: String,
    weights: String,
    rpc_url: String,
    num_threads: u32,
    max_gen: u32,
    max_think: u32,
    max_steps: u32,
    allow_eval: bool,
    greedy: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct TuiConfig {
    title: String,
    show_help: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct KeybindingConfig {
    submit: String,
    quit: String,
    clear: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            startup: StartupConfig {
                rscript: "Rscript".to_string(),
                weights: String::new(),
                rpc_url: "http://127.0.0.1:8080".to_string(),
                num_threads: 2,
                max_gen: 256,
                max_think: 48,
                max_steps: 4,
                allow_eval: true,
                greedy: true,
            },
            tui: TuiConfig {
                title: "Rbebelm".to_string(),
                show_help: true,
            },
            keybindings: KeybindingConfig {
                submit: "enter".to_string(),
                quit: "ctrl-q".to_string(),
                clear: "ctrl-l".to_string(),
            },
        }
    }
}

#[derive(Debug, Deserialize)]
struct RpcResponse {
    result: Option<Value>,
    error: Option<RpcError>,
}

#[derive(Debug, Deserialize)]
struct RpcError {
    code: Value,
    message: String,
}

#[derive(Debug, Clone)]
struct ChatMessage {
    role: &'static str,
    text: String,
}

#[derive(Debug, Clone)]
struct CommandInfo {
    name: String,
    description: String,
    usage: String,
}

const HEADLESS_R: &str = r#"
json_flag <- identical(Sys.getenv("RBEBELM_TUI_JSON"), "true")
json_line <- function(x) {
  if (!requireNamespace("yyjsonr", quietly = TRUE)) stop("yyjsonr is required", call. = FALSE)
  cat(yyjsonr::write_json_str(x), "\n", sep = "")
  flush.console()
}
num <- function(name, default) {
  value <- suppressWarnings(as.numeric(Sys.getenv(name, as.character(default))))
  if (is.na(value)) default else value
}
logical_env <- function(name, default = FALSE) {
  value <- tolower(Sys.getenv(name, if (default) "true" else "false"))
  value %in% c("1", "true", "yes", "on")
}
tryCatch({
  suppressPackageStartupMessages(library(Rbebelm))
  if (!requireNamespace("nanonext", quietly = TRUE)) {
    stop("rbebelm-tui headless requires optional R package 'nanonext'", call. = FALSE)
  }
  if (!requireNamespace("later", quietly = TRUE)) {
    stop("rbebelm-tui headless requires optional R package 'later'", call. = FALSE)
  }
  weights <- Sys.getenv("RBEBELM_TUI_WEIGHTS", Sys.getenv("BEBELM_WEIGHTS_FILE", ""))
  if (!nzchar(weights)) stop("Set --weights or BEBELM_WEIGHTS_FILE", call. = FALSE)
  url <- Sys.getenv("RBEBELM_TUI_RPC_URL", "http://127.0.0.1:8080")
  model <- bebel_model_load(weights, num_threads = num("RBEBELM_TUI_NUM_THREADS", 2))
  session <- bebel_r_agent(
    model,
    allow_eval = logical_env("RBEBELM_TUI_ALLOW_EVAL", FALSE),
    greedy = logical_env("RBEBELM_TUI_GREEDY", TRUE),
    max_gen = num("RBEBELM_TUI_MAX_GEN", 256),
    max_think = num("RBEBELM_TUI_MAX_THINK", 48)
  )
  loop <- bebel_r_agent_loop(
    session,
    policy = bebel_loop_policy(max_steps = as.integer(num("RBEBELM_TUI_MAX_STEPS", 4))),
    agent_session = TRUE
  )
  server <- bebel_loop_rpc_server(loop, url = url)
  if (is.function(server$start)) server$start()
  on.exit(if (is.function(server$close)) try(server$close(), silent = TRUE), add = TRUE)
  info <- list(
    ready = TRUE,
    host_kind = "bebelm-local-loop",
    endpoint_protocol = "rbebelm-loop-stream-command-v1",
    pid = Sys.getpid(),
    url = url,
    cwd = getwd(),
    weights = normalizePath(weights, winslash = "/", mustWork = FALSE),
    max_steps = num("RBEBELM_TUI_MAX_STEPS", 4)
  )
  if (json_flag) json_line(info) else message("Rbebelm loop endpoint ready at ", url, " (pid ", Sys.getpid(), ")")
  repeat {
    later::run_now(0.1)
    Sys.sleep(0.01)
  }
}, error = function(e) {
  if (json_flag) json_line(list(ready = FALSE, error = conditionMessage(e))) else message("ERROR: ", conditionMessage(e))
  quit(status = 1L)
})
"#;

fn main() -> Result<()> {
    let cli = Cli::parse();
    let config_path = resolve_config_path(cli.config.clone())?;
    let config = load_config(&config_path)?;

    match cli.command.unwrap_or_else(|| CommandKind::Run(RunArgs::default())) {
        CommandKind::Run(args) => run_local(args.into(), &config),
        CommandKind::Config(args) => run_config(args, &config_path),
        CommandKind::Headless(args) => run_headless(args, &config),
        CommandKind::Rpc(args) => run_rpc(args, &config),
        CommandKind::Command(args) => run_command(args, &config),
        CommandKind::Stream(args) => run_stream(args, &config),
        CommandKind::Chat(args) => run_chat(args, &config),
    }
}

fn resolve_config_path(path: Option<PathBuf>) -> Result<PathBuf> {
    if let Some(path) = path {
        return Ok(path);
    }
    let base = dirs::config_dir().ok_or_else(|| anyhow!("could not resolve a config directory"))?;
    Ok(base.join("rbebelm").join("tui.toml"))
}

fn default_config_toml() -> Result<String> {
    toml::to_string_pretty(&Config::default()).context("failed to serialize default config")
}

fn load_config(path: &PathBuf) -> Result<Config> {
    if !path.exists() {
        return Ok(Config::default());
    }
    let text = fs::read_to_string(path).with_context(|| format!("failed to read {}", path.display()))?;
    toml::from_str(&text).with_context(|| format!("failed to parse {}", path.display()))
}

fn run_config(args: ConfigCommand, path: &PathBuf) -> Result<()> {
    match args.command {
        ConfigSubcommand::Path => {
            println!("{}", path.display());
        }
        ConfigSubcommand::Default => {
            print!("{}", default_config_toml()?);
        }
        ConfigSubcommand::Init { force } => {
            if path.exists() && !force {
                return Err(anyhow!(
                    "{} already exists; pass --force to overwrite",
                    path.display()
                ));
            }
            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent).with_context(|| format!("failed to create {}", parent.display()))?;
            }
            fs::write(path, default_config_toml()?)
                .with_context(|| format!("failed to write {}", path.display()))?;
            println!("wrote {}", path.display());
        }
    }
    Ok(())
}

fn resolve_headless_config(args: HeadlessArgs, config: &Config, json_override: Option<bool>) -> Result<HeadlessConfig> {
    let weights = args
        .weights
        .or_else(|| (!config.startup.weights.is_empty()).then(|| config.startup.weights.clone()))
        .or_else(|| std::env::var("BEBELM_WEIGHTS_FILE").ok())
        .ok_or_else(|| anyhow!("provide --weights, config startup.weights, or BEBELM_WEIGHTS_FILE"))?;
    Ok(HeadlessConfig {
        weights,
        url: args.url.unwrap_or_else(|| config.startup.rpc_url.clone()),
        rscript: args.rscript.unwrap_or_else(|| config.startup.rscript.clone()),
        num_threads: args.num_threads.unwrap_or(config.startup.num_threads),
        max_gen: args.max_gen.unwrap_or(config.startup.max_gen),
        max_think: args.max_think.unwrap_or(config.startup.max_think),
        max_steps: args.max_steps.unwrap_or(config.startup.max_steps),
        allow_eval: if args.no_eval { false } else { args.allow_eval || config.startup.allow_eval },
        greedy: if args.sample { false } else { config.startup.greedy },
        json: json_override.unwrap_or(args.json),
    })
}

fn headless_command(cfg: &HeadlessConfig) -> Command {
    let mut command = Command::new(&cfg.rscript);
    command
        .arg("--vanilla")
        .arg("-e")
        .arg(HEADLESS_R)
        .env("RBEBELM_TUI_WEIGHTS", &cfg.weights)
        .env("RBEBELM_TUI_RPC_URL", &cfg.url)
        .env("RBEBELM_TUI_NUM_THREADS", cfg.num_threads.to_string())
        .env("RBEBELM_TUI_MAX_GEN", cfg.max_gen.to_string())
        .env("RBEBELM_TUI_MAX_THINK", cfg.max_think.to_string())
        .env("RBEBELM_TUI_MAX_STEPS", cfg.max_steps.to_string())
        .env("RBEBELM_TUI_ALLOW_EVAL", bool_env(cfg.allow_eval))
        .env("RBEBELM_TUI_GREEDY", bool_env(cfg.greedy))
        .env("RBEBELM_TUI_JSON", bool_env(cfg.json));
    command
}

fn run_headless(args: HeadlessArgs, config: &Config) -> Result<()> {
    let cfg = resolve_headless_config(args, config, None)?;
    let mut child = headless_command(&cfg)
        .spawn()
        .with_context(|| format!("failed to start {}", cfg.rscript))?;

    let status = child.wait().context("failed waiting for R headless host")?;
    if !status.success() {
        return Err(anyhow!("R headless host exited with status {status}"));
    }
    Ok(())
}

fn run_local(args: HeadlessArgs, config: &Config) -> Result<()> {
    let cfg = resolve_headless_config(args, config, Some(true))?;
    eprintln!("Starting Rbebelm local host at {} ...", cfg.url);
    let mut command = headless_command(&cfg);
    command.stdout(Stdio::piped()).stderr(Stdio::inherit());
    let mut child = command
        .spawn()
        .with_context(|| format!("failed to start {}", cfg.rscript))?;

    let ready = wait_for_headless_ready(&mut child, Duration::from_secs(180))
        .inspect_err(|_| stop_child(&mut child))?;
    if !json_bool(ready.get("ready")) {
        stop_child(&mut child);
        let msg = ready.get("error").and_then(value_string).unwrap_or_else(|| ready.to_string());
        return Err(anyhow!("R host failed to start: {msg}"));
    }
    let url = ready.get("url").and_then(value_string).unwrap_or_else(|| cfg.url.clone());
    eprintln!("Rbebelm host ready at {url}; launching chat. Ctrl-Q exits and stops the host.");

    let commands = fetch_command_catalog(&url).unwrap_or_default();
    let (tx, rx) = mpsc::channel();
    spawn_stream_thread(url.clone(), tx.clone());
    let mut app = ChatApp::new(config.tui.title.clone(), url.clone(), cfg.max_steps, config.tui.show_help, rx, tx, commands);
    app.status = format!("Started local R host at {url}; /help or Tab after / for commands; /quit exits");
    let result = run_terminal(&mut app);
    stop_child(&mut child);
    result
}

fn wait_for_headless_ready(child: &mut Child, timeout: Duration) -> Result<Value> {
    let stdout = child.stdout.take().ok_or_else(|| anyhow!("headless child stdout was not piped"))?;
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        let mut reader = BufReader::new(stdout);
        let mut line = String::new();
        let first = match reader.read_line(&mut line) {
            Ok(0) => Err("headless host closed stdout before readiness".to_string()),
            Ok(_) => Ok(line),
            Err(e) => Err(format!("failed to read headless readiness: {e}")),
        };
        let _ = tx.send(first);
        for line in reader.lines() {
            if line.is_err() { break; }
        }
    });

    let start = Instant::now();
    loop {
        if let Ok(line) = rx.try_recv() {
            let line = line.map_err(|e| anyhow!(e))?;
            return serde_json::from_str(line.trim()).with_context(|| format!("invalid readiness JSON: {line}"));
        }
        if let Some(status) = child.try_wait().context("failed polling R headless host")? {
            return Err(anyhow!("R headless host exited before readiness with status {status}"));
        }
        if start.elapsed() > timeout {
            return Err(anyhow!("timed out waiting for R headless host readiness"));
        }
        thread::sleep(Duration::from_millis(100));
    }
}

fn stop_child(child: &mut Child) {
    if matches!(child.try_wait(), Ok(None)) {
        let _ = child.kill();
    }
    let _ = child.wait();
}

fn json_bool(value: Option<&Value>) -> bool {
    match value {
        Some(Value::Bool(x)) => *x,
        Some(Value::Array(xs)) => xs.first().and_then(Value::as_bool).unwrap_or(false),
        _ => false,
    }
}

fn value_string(value: &Value) -> Option<String> {
    match value {
        Value::String(x) => Some(x.clone()),
        Value::Array(xs) => xs.first().and_then(Value::as_str).map(ToString::to_string),
        _ => None,
    }
}

fn fetch_command_catalog(url: &str) -> Result<Vec<CommandInfo>> {
    let value = command_call(url, json!({"type":"commands_list"}))?;
    Ok(parse_command_catalog(value.get("commands").unwrap_or(&Value::Null)))
}

fn local_command_catalog() -> Vec<CommandInfo> {
    vec![
        CommandInfo { name: "quit".to_string(), description: "Quit the TUI.".to_string(), usage: "/quit".to_string() },
        CommandInfo { name: "exit".to_string(), description: "Quit the TUI.".to_string(), usage: "/exit".to_string() },
        CommandInfo { name: "q".to_string(), description: "Quit the TUI.".to_string(), usage: "/q".to_string() },
    ]
}

fn format_command_infos(title: &str, commands: &[CommandInfo]) -> String {
    if commands.is_empty() { return format!("{title}\n(none)"); }
    let mut lines = vec![format!("{title}:")];
    for cmd in commands {
        let usage = if cmd.usage.is_empty() { format!("/{}", cmd.name) } else { cmd.usage.clone() };
        if cmd.description.is_empty() {
            lines.push(format!("- {usage}"));
        } else {
            lines.push(format!("- {usage} - {}", cmd.description));
        }
    }
    lines.join("\n")
}

fn parse_command_catalog(value: &Value) -> Vec<CommandInfo> {
    let Some(names) = value.get("name").and_then(Value::as_array) else { return Vec::new(); };
    let descs = value.get("description").and_then(Value::as_array);
    let usages = value.get("usage").and_then(Value::as_array);
    names.iter().enumerate().filter_map(|(i, name)| {
        let name = name.as_str()?.to_string();
        let description = descs
            .and_then(|xs| xs.get(i))
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string();
        let usage = usages
            .and_then(|xs| xs.get(i))
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string();
        Some(CommandInfo { name, description, usage })
    }).collect()
}

fn run_rpc(args: RpcArgs, config: &Config) -> Result<()> {
    let url = args.url.unwrap_or_else(|| config.startup.rpc_url.clone());
    let params: Value = serde_json::from_str(&args.params).context("--params must be a JSON value")?;
    let result = rpc_call(&url, &args.method, params)?;
    println!("{}", serde_json::to_string_pretty(&result)?);
    Ok(())
}

fn run_command(args: CommandArgs, config: &Config) -> Result<()> {
    let url = args.url.unwrap_or_else(|| config.startup.rpc_url.clone());
    let mut command: Value = serde_json::from_str(&args.params).context("--params must be a JSON object")?;
    if !command.is_object() {
        return Err(anyhow!("--params must be a JSON object"));
    }
    command["type"] = Value::String(args.r#type);
    let result = command_call(&url, command)?;
    println!("{}", serde_json::to_string_pretty(&result)?);
    Ok(())
}

fn run_stream(args: StreamArgs, config: &Config) -> Result<()> {
    let url = args.url.unwrap_or_else(|| config.startup.rpc_url.clone());
    let response = ureq::get(&stream_endpoint(&url, args.since))
        .call()
        .with_context(|| format!("stream request to {} failed", stream_endpoint(&url, args.since)))?;
    let reader = BufReader::new(response.into_reader());
    for line in reader.lines() {
        println!("{}", line.context("failed to read stream line")?);
        io::stdout().flush().ok();
    }
    Ok(())
}

fn run_chat(args: ChatArgs, config: &Config) -> Result<()> {
    let url = args.url.unwrap_or_else(|| config.startup.rpc_url.clone());
    let max_steps = args.max_steps.unwrap_or(config.startup.max_steps);
    let commands = fetch_command_catalog(&url).unwrap_or_default();
    let (tx, rx) = mpsc::channel();
    spawn_stream_thread(url.clone(), tx.clone());
    let mut app = ChatApp::new(config.tui.title.clone(), url, max_steps, config.tui.show_help, rx, tx, commands);
    run_terminal(&mut app)
}

fn bool_env(value: bool) -> &'static str {
    if value { "true" } else { "false" }
}

fn endpoint(base: &str, suffix: &str) -> String {
    let trimmed = base.trim_end_matches('/');
    if trimmed.ends_with(suffix) {
        trimmed.to_string()
    } else {
        format!("{trimmed}{suffix}")
    }
}

fn rpc_endpoint(base: &str) -> String {
    endpoint(base, "/rpc")
}

fn command_endpoint(base: &str) -> String {
    endpoint(base, "/command")
}

fn stream_endpoint(base: &str, since: u64) -> String {
    let base = endpoint(base, "/stream");
    if since == 0 { base } else { format!("{base}?since={since}") }
}

fn rpc_call(base_url: &str, method: &str, params: Value) -> Result<Value> {
    let body = json!({"jsonrpc": "2.0", "id": 1, "method": method, "params": params});
    let response = ureq::post(&rpc_endpoint(base_url))
        .set("Content-Type", "application/json")
        .send_string(&serde_json::to_string(&body)?)
        .with_context(|| format!("RPC request to {} failed", rpc_endpoint(base_url)))?;
    let text = response.into_string().context("failed to read RPC response")?;
    let parsed: RpcResponse = serde_json::from_str(&text).with_context(|| format!("invalid RPC response: {text}"))?;
    if let Some(error) = parsed.error {
        return Err(anyhow!("RPC error {}: {}", error.code, error.message));
    }
    parsed.result.ok_or_else(|| anyhow!("RPC response did not include result"))
}

fn command_call(base_url: &str, command: Value) -> Result<Value> {
    let response = ureq::post(&command_endpoint(base_url))
        .set("Content-Type", "application/json")
        .send_string(&serde_json::to_string(&command)?)
        .with_context(|| format!("command request to {} failed", command_endpoint(base_url)))?;
    let text = response.into_string().context("failed to read command response")?;
    let parsed: Value = serde_json::from_str(&text).with_context(|| format!("invalid command response: {text}"))?;
    if parsed.get("type").and_then(Value::as_str) == Some("error") {
        let msg = parsed.pointer("/error/message").and_then(Value::as_str).unwrap_or("unknown command error");
        return Err(anyhow!("command error: {msg}"));
    }
    Ok(parsed)
}

fn spawn_stream_thread(url: String, tx: Sender<Value>) {
    thread::spawn(move || {
        let stream_url = stream_endpoint(&url, 0);
        let result = (|| -> Result<()> {
            let response = ureq::get(&stream_url)
                .call()
                .with_context(|| format!("stream request to {stream_url} failed"))?;
            let reader = BufReader::new(response.into_reader());
            for line in reader.lines() {
                let line = line.context("failed to read stream line")?;
                if line.trim().is_empty() { continue; }
                let value: Value = serde_json::from_str(&line).with_context(|| format!("invalid stream event: {line}"))?;
                if tx.send(value).is_err() { break; }
            }
            Ok(())
        })();
        if let Err(err) = result {
            let _ = tx.send(json!({"type":"client_error","message":err.to_string()}));
        }
    });
}

struct ChatApp {
    title: String,
    url: String,
    max_steps: u32,
    show_help: bool,
    input: String,
    status: String,
    messages: Vec<ChatMessage>,
    should_quit: bool,
    event_rx: Receiver<Value>,
    event_tx: Sender<Value>,
    command_in_flight: bool,
    command_catalog: Vec<CommandInfo>,
    busy_started: Option<Instant>,
    busy_label: String,
    observed_loop_state: String,
    last_loop_state: Option<Value>,
    last_event_seq: Option<u64>,
}

impl ChatApp {
    fn new(title: String, url: String, max_steps: u32, show_help: bool, event_rx: Receiver<Value>, event_tx: Sender<Value>, command_catalog: Vec<CommandInfo>) -> Self {
        Self {
            title,
            url,
            max_steps,
            show_help,
            input: String::new(),
            status: "Connecting... /help or Tab after / for commands; /quit exits".to_string(),
            messages: Vec::new(),
            should_quit: false,
            event_rx,
            event_tx,
            command_in_flight: false,
            command_catalog,
            busy_started: None,
            busy_label: String::new(),
            observed_loop_state: "unknown".to_string(),
            last_loop_state: None,
            last_event_seq: None,
        }
    }

    fn begin_busy(&mut self, label: &str) {
        self.command_in_flight = true;
        self.busy_started = Some(Instant::now());
        self.busy_label = label.to_string();
        self.status = label.to_string();
    }

    fn end_busy(&mut self, status: &str) {
        self.command_in_flight = false;
        self.busy_started = None;
        self.busy_label.clear();
        self.status = status.to_string();
    }

    fn busy_status(&self) -> Option<String> {
        self.busy_started.map(|started| {
            let secs = started.elapsed().as_secs();
            format!("{} {}s", self.busy_label, secs)
        })
    }

    fn submit(&mut self) {
        let prompt = self.input.trim().to_string();
        if prompt.is_empty() {
            self.status = "Prompt is empty".to_string();
            return;
        }
        self.input.clear();
        if self.handle_local_slash(&prompt) {
            return;
        }
        if self.command_in_flight {
            self.status = "Command already in flight; wait or use steer/followUp later".to_string();
            return;
        }
        self.messages.push(ChatMessage { role: "user", text: prompt.clone() });
        let url = self.url.clone();
        let max_steps = self.max_steps;
        let tx = self.event_tx.clone();
        if is_remote_slash(&prompt) {
            self.begin_busy("Executing slash command...");
            thread::spawn(move || {
                let result = command_call(&url, json!({"type":"execute_command", "command": prompt}));
                match result {
                    Ok(value) => { let _ = tx.send(json!({"type":"client_command_result", "result": value})); }
                    Err(err) => { let _ = tx.send(json!({"type":"client_error", "message": err.to_string()})); }
                }
            });
        } else {
            self.begin_busy("Waiting for R/model prefill...");
            thread::spawn(move || {
                let result = command_call(&url, json!({"type":"turn", "prompt": prompt, "max_steps": max_steps}));
                match result {
                    Ok(value) => { let _ = tx.send(json!({"type":"client_command_result", "result": value})); }
                    Err(err) => { let _ = tx.send(json!({"type":"client_error", "message": err.to_string()})); }
                }
            });
        }
    }

    fn handle_local_slash(&mut self, prompt: &str) -> bool {
        let cmd = prompt.split_whitespace().next().unwrap_or("").to_ascii_lowercase();
        match cmd.as_str() {
            "/q" | "/quit" | "/exit" => {
                self.should_quit = true;
                true
            }
            "/state" if self.command_in_flight => {
                self.push_observed_state();
                true
            }
            "/help" | "/commands" if self.command_in_flight => {
                self.push_cached_command_help();
                true
            }
            "//" => false,
            _ => false,
        }
    }

    fn push_cached_command_help(&mut self) {
        let mut commands = self.command_catalog.clone();
        commands.extend(local_command_catalog());
        let text = format_command_infos("Slash commands (cached)", &commands);
        self.messages.push(ChatMessage { role: "command", text });
        self.status = "Showing cached command catalog while the R loop is busy".to_string();
    }

    fn push_observed_state(&mut self) {
        let mut lines = vec!["Frontend-observed loop state".to_string()];
        lines.push(format!("state: {}", self.observed_loop_state));
        lines.push(format!("command in flight: {}", if self.command_in_flight { "yes" } else { "no" }));
        if let Some(busy) = self.busy_status() { lines.push(format!("busy: {busy}")); }
        if let Some(seq) = self.last_event_seq { lines.push(format!("last event seq: {seq}")); }
        if let Some(state) = &self.last_loop_state {
            push_state_field(&mut lines, state, "turns", "turns");
            push_state_field(&mut lines, state, "tool_calls", "tool calls");
            push_state_field(&mut lines, state, "user_messages", "user messages");
            push_state_field(&mut lines, state, "observations", "observations");
            push_state_field(&mut lines, state, "queue", "queue");
            push_state_field(&mut lines, state, "commands", "commands");
            push_state_field(&mut lines, state, "extensions", "extensions");
        }
        lines.push("note: R is running the active turn, so /state is served from the TUI stream cache until the turn finishes.".to_string());
        self.messages.push(ChatMessage { role: "state", text: lines.join("\n") });
        self.status = "Showing locally observed state while the R loop is busy".to_string();
    }

    fn clear(&mut self) {
        self.messages.clear();
        self.status = "Local screen cleared".to_string();
    }

    fn process_events(&mut self) {
        while let Ok(record) = self.event_rx.try_recv() {
            self.process_event_record(record);
        }
    }

    fn process_event_record(&mut self, record: Value) {
        match record.get("type").and_then(Value::as_str).unwrap_or("") {
            "stream_open" => {
                if let Some(state) = record.get("state") { self.update_observed_state_from_snapshot(state); }
                if let Some(seq) = record.get("seq").and_then(Value::as_u64) { self.last_event_seq = Some(seq); }
                self.status = "Connected. /help or Tab after / for commands; /quit exits".to_string();
            }
            "client_error" => {
                self.end_busy("Client error");
                self.messages.push(ChatMessage { role: "error", text: record.get("message").and_then(Value::as_str).unwrap_or("client error").to_string() });
            }
            "client_command_result" => {
                self.end_busy("Ready");
                if record.pointer("/result/type").and_then(Value::as_str) == Some("command_result") {
                    if record.pointer("/result/result").and_then(Value::as_bool) == Some(false) {
                        self.messages.push(ChatMessage { role: "error", text: "Unknown slash command. Try /help or press Tab after /.".to_string() });
                    }
                } else if !self.has_recent_assistant_text() {
                    if let Some(text) = record.pointer("/result/text").and_then(Value::as_str) {
                        if !text.is_empty() {
                            self.messages.push(ChatMessage { role: "assistant", text: text.to_string() });
                        }
                    }
                }
            }
            "event" => {
                if let Some(event) = record.get("event") {
                    self.process_loop_event(event);
                }
            }
            other => self.status = format!("Unhandled stream record: {other}"),
        }
    }

    fn process_loop_event(&mut self, event: &Value) {
        if let Some(seq) = event.get("seq").and_then(Value::as_u64) { self.last_event_seq = Some(seq); }
        match event.get("type").and_then(Value::as_str).unwrap_or("") {
            "state_change" => {
                let to = event.get("to").and_then(Value::as_str).unwrap_or("?");
                self.update_observed_state_name(to);
                if self.command_in_flight {
                    self.busy_label = match to {
                        "running" => "Running loop...".to_string(),
                        "generating" => "Prefilling prompt / waiting for first token...".to_string(),
                        "tool_pending" => "Preparing tool call...".to_string(),
                        "tool_running" => "Running tool...".to_string(),
                        other => format!("state: {other}"),
                    };
                }
                self.status = format!("state: {to}");
            }
            "message_start" => {
                if let Some(src) = event.get("source").and_then(Value::as_str) {
                    self.status = format!("message: {src}");
                }
            }
            "model_event" => {
                if let Some(model_event) = event.get("model_event") {
                    self.process_model_event(model_event);
                }
            }
            "tool_request" => {
                let name = event.pointer("/call/name").and_then(Value::as_str).unwrap_or("tool");
                self.increment_observed_counter("tool_calls");
                self.busy_label = format!("Running tool {name}...");
                self.messages.push(ChatMessage { role: "tool", text: format!("request: {name}") });
            }
            "tool_result" => {
                let name = event.pointer("/call/name").and_then(Value::as_str).unwrap_or("tool");
                let result = event.get("result").map(|v| value_preview(v)).unwrap_or_default();
                if let Some(path) = plot_path_from_text(&result) {
                    self.messages.push(ChatMessage { role: "artifact", text: png_artifact_text(&path, None) });
                } else {
                    self.messages.push(ChatMessage { role: "tool", text: format!("result {name}: {result}") });
                }
            }
            "tool_error" | "tool_denied" => {
                let name = event.pointer("/call/name").and_then(Value::as_str).unwrap_or("tool");
                let msg = event.pointer("/error/message").and_then(Value::as_str).unwrap_or("tool error");
                self.messages.push(ChatMessage { role: "error", text: format!("{name}: {msg}") });
            }
            "command_end" => {
                let name = event.get("command").and_then(Value::as_str).unwrap_or("command");
                let result = event.get("result").map(value_preview).unwrap_or_else(|| "OK".to_string());
                if let Some(path) = plot_path_from_text(&result) {
                    self.messages.push(ChatMessage { role: "artifact", text: png_artifact_text(&path, Some(name)) });
                } else {
                    self.messages.push(ChatMessage { role: "command", text: format!("/{name}: {result}") });
                }
            }
            "command_error" => {
                let name = event.get("command").and_then(Value::as_str).unwrap_or("command");
                let msg = event.get("message").and_then(Value::as_str).unwrap_or("command error");
                self.messages.push(ChatMessage { role: "error", text: format!("/{name}: {msg}") });
            }
            "turn_end" => {
                self.increment_observed_counter("turns");
            }
            "catalog_changed" => {
                if let Ok(commands) = fetch_command_catalog(&self.url) {
                    self.command_catalog = commands;
                    self.status = "Command catalog refreshed".to_string();
                }
            }
            "loop_end" => self.status = "loop ended".to_string(),
            _ => {}
        }
    }

    fn process_model_event(&mut self, event: &Value) {
        match event.get("type").and_then(Value::as_str).unwrap_or("") {
            "start" => self.busy_label = "Model started; waiting for first token...".to_string(),
            "thinking_start" => {
                self.busy_label = "Streaming thinking...".to_string();
                self.messages.push(ChatMessage { role: "thinking", text: String::new() });
            }
            "thinking_delta" => self.append_delta("thinking", event.get("delta").and_then(Value::as_str).unwrap_or("")),
            "text_start" => {
                self.busy_label = "Streaming answer...".to_string();
                self.messages.push(ChatMessage { role: "assistant", text: String::new() });
            }
            "text_delta" => self.append_delta("assistant", event.get("delta").and_then(Value::as_str).unwrap_or("")),
            "tool_call_start" => {
                self.busy_label = "Streaming tool call...".to_string();
                self.messages.push(ChatMessage { role: "tool_call", text: String::new() });
            }
            "tool_call_delta" => self.append_delta("tool_call", event.get("delta").and_then(Value::as_str).unwrap_or("")),
            "done" => self.status = "model done".to_string(),
            _ => {}
        }
    }

    fn append_delta(&mut self, role: &'static str, delta: &str) {
        if delta.is_empty() { return; }
        if let Some(last) = self.messages.last_mut() {
            if last.role == role {
                last.text.push_str(delta);
                return;
            }
        }
        self.messages.push(ChatMessage { role, text: delta.to_string() });
    }

    fn complete_slash(&mut self) {
        if !self.input.starts_with('/') || self.input.starts_with("//") {
            self.status = "Tab completion is for slash commands".to_string();
            return;
        }
        let prefix = self.input.trim_start_matches('/');
        let prefix = prefix.split_whitespace().next().unwrap_or("");
        let mut matches: Vec<&CommandInfo> = self
            .command_catalog
            .iter()
            .filter(|cmd| cmd.name.starts_with(prefix))
            .collect();
        let local = local_command_catalog();
        let mut local_matches: Vec<&CommandInfo> = local.iter().filter(|cmd| cmd.name.starts_with(prefix)).collect();
        matches.append(&mut local_matches);
        if matches.is_empty() {
            self.status = format!("No command matches /{prefix}");
        } else if matches.len() == 1 {
            self.input = format!("/{} ", matches[0].name);
            self.status = format!("{} — {}", matches[0].usage, matches[0].description);
        } else {
            let shown = matches.iter().take(8).map(|cmd| format!("/{}", cmd.name)).collect::<Vec<_>>().join(" ");
            self.status = format!("Commands: {shown}");
        }
    }

    fn update_observed_state_from_snapshot(&mut self, state: &Value) {
        self.last_loop_state = Some(state.clone());
        if let Some(name) = state.get("state").and_then(Value::as_str) {
            self.observed_loop_state = name.to_string();
        }
    }

    fn update_observed_state_name(&mut self, name: &str) {
        self.observed_loop_state = name.to_string();
        if let Some(Value::Object(map)) = self.last_loop_state.as_mut() {
            map.insert("state".to_string(), Value::String(name.to_string()));
        }
    }

    fn increment_observed_counter(&mut self, key: &str) {
        let Some(Value::Object(map)) = self.last_loop_state.as_mut() else { return; };
        let next = map.get(key).and_then(Value::as_u64).unwrap_or(0).saturating_add(1);
        map.insert(key.to_string(), Value::Number(serde_json::Number::from(next)));
    }

    fn has_recent_assistant_text(&self) -> bool {
        self.messages.iter().rev().take(4).any(|m| m.role == "assistant" && !m.text.is_empty())
    }
}

fn is_remote_slash(prompt: &str) -> bool {
    prompt.starts_with('/') && !prompt.starts_with("//")
}

fn plot_path_from_text(text: &str) -> Option<String> {
    let marker = "Plot saved to:";
    let idx = text.find(marker)?;
    let rest = text[idx + marker.len()..].trim();
    let path = rest.lines().next().unwrap_or("").trim();
    if path.ends_with(".png") { Some(path.to_string()) } else { None }
}

fn png_artifact_text(path: &str, command: Option<&str>) -> String {
    let header = match command {
        Some(name) => format!("/{name}: image/png\n{path}"),
        None => format!("image/png: {path}"),
    };
    match png_text_preview(path) {
        Some(preview) => format!("{header}\n{preview}\nPreview: monochrome terminal thumbnail; open the PNG path above for full fidelity."),
        None => format!("{header}\nPreview unavailable; open the PNG path above."),
    }
}

fn png_text_preview(path: &str) -> Option<String> {
    let img = image::open(path).ok()?;
    let gray = img.to_luma8();
    let (width, height) = gray.dimensions();
    if width == 0 || height == 0 { return None; }
    let max_cols = 72.0_f64;
    let max_rows = 24.0_f64;
    let scale = (width as f64 / max_cols).max(height as f64 / max_rows).max(1.0);
    let cols = ((width as f64 / scale).round() as u32).max(1);
    let rows = ((height as f64 / scale).round() as u32).max(1);
    let thumb = image::imageops::resize(&gray, cols, rows, image::imageops::FilterType::Triangle);
    let ramp = b" .:-=+*#%@";
    let mut lines = Vec::with_capacity(rows as usize + 2);
    lines.push(format!("thumbnail: {width}x{height} -> {cols}x{rows} chars"));
    for y in 0..rows {
        let mut line = String::with_capacity(cols as usize);
        for x in 0..cols {
            let lum = thumb.get_pixel(x, y)[0] as usize;
            let idx = ((255usize.saturating_sub(lum)) * (ramp.len() - 1) / 255).min(ramp.len() - 1);
            line.push(ramp[idx] as char);
        }
        lines.push(line.trim_end().to_string());
    }
    Some(lines.join("\n"))
}

fn value_inline(value: &Value) -> String {
    match value {
        Value::Null => "null".to_string(),
        Value::Bool(x) => x.to_string(),
        Value::Number(x) => x.to_string(),
        Value::String(x) => x.clone(),
        Value::Array(xs) if xs.iter().all(Value::is_string) => xs.iter().filter_map(Value::as_str).collect::<Vec<_>>().join(", "),
        _ => serde_json::to_string(value).unwrap_or_else(|_| String::new()),
    }
}

fn push_state_field(lines: &mut Vec<String>, state: &Value, key: &str, label: &str) {
    if let Some(value) = state.get(key) {
        lines.push(format!("{label}: {}", value_inline(value)));
    }
}

fn value_preview(value: &Value) -> String {
    if let Some(s) = value.as_str() { return s.to_string(); }
    serde_json::to_string(value).unwrap_or_else(|_| String::new())
}

fn run_terminal(app: &mut ChatApp) -> Result<()> {
    enable_raw_mode().context("failed to enable raw mode")?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen).context("failed to enter alternate screen")?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend).context("failed to initialize terminal")?;

    let result = run_terminal_loop(&mut terminal, app);

    disable_raw_mode().ok();
    execute!(terminal.backend_mut(), LeaveAlternateScreen).ok();
    terminal.show_cursor().ok();
    result
}

fn run_terminal_loop<W: Write>(terminal: &mut Terminal<CrosstermBackend<W>>, app: &mut ChatApp) -> Result<()> {
    while !app.should_quit {
        app.process_events();
        draw(terminal, app)?;
        if event::poll(Duration::from_millis(150)).context("failed to poll terminal events")? {
            if let Event::Key(key) = event::read().context("failed to read terminal event")? {
                handle_key(app, key);
            }
        }
    }
    Ok(())
}

fn role_color(role: &str) -> Color {
    match role {
        "user" => Color::Cyan,
        "assistant" => Color::Green,
        "error" => Color::Red,
        "command" => Color::Magenta,
        "state" => Color::Cyan,
        "artifact" => Color::Blue,
        "tool" | "tool_call" => Color::Yellow,
        "thinking" => Color::DarkGray,
        _ => Color::Yellow,
    }
}

fn markdown_line_style(text: &str, role: &str) -> Style {
    let trimmed = text.trim_start();
    let base = Style::default().fg(role_color(role));
    if trimmed.starts_with("#") {
        base.add_modifier(Modifier::BOLD)
    } else if trimmed.starts_with("```") || trimmed.starts_with("    ") {
        Style::default().fg(Color::Gray)
    } else if trimmed.starts_with("-") || trimmed.starts_with("*") {
        base
    } else {
        base
    }
}

fn render_message_lines(lines: &mut Vec<Line<'static>>, message: &ChatMessage) {
    let color = role_color(message.role);
    let parts: Vec<&str> = if message.text.is_empty() {
        vec![""]
    } else {
        message.text.lines().collect()
    };
    if parts.is_empty() {
        lines.push(Line::from(vec![Span::styled(
            format!("{}: ", message.role),
            Style::default().fg(color).add_modifier(Modifier::BOLD),
        )]));
        return;
    }
    for (i, part) in parts.iter().enumerate() {
        let prefix = if i == 0 { format!("{}: ", message.role) } else { "  ".to_string() };
        lines.push(Line::from(vec![
            Span::styled(prefix, Style::default().fg(color).add_modifier(Modifier::BOLD)),
            Span::styled((*part).to_string(), markdown_line_style(part, message.role)),
        ]));
    }
}

fn draw<W: Write>(terminal: &mut Terminal<CrosstermBackend<W>>, app: &ChatApp) -> Result<()> {
    terminal.draw(|frame| {
        let area = frame.area();
        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Min(3), Constraint::Length(3), Constraint::Length(1)])
            .split(area);

        let mut lines = Vec::new();
        for message in app.messages.iter().rev().take(80).rev() {
            render_message_lines(&mut lines, message);
            lines.push(Line::raw(""));
        }
        let title = if let Some(busy) = app.busy_status() {
            format!("{} — {}", app.title, busy)
        } else {
            app.title.clone()
        };
        let transcript = Paragraph::new(lines)
            .block(Block::default().title(title).borders(Borders::ALL))
            .wrap(Wrap { trim: false });
        frame.render_widget(transcript, chunks[0]);

        let input = Paragraph::new(app.input.as_str())
            .block(Block::default().title("Prompt").borders(Borders::ALL))
            .style(Style::default().fg(Color::White));
        frame.render_widget(input, chunks[1]);

        let base_status = app.busy_status().unwrap_or_else(|| app.status.clone());
        let help = if app.show_help {
            format!("{} | Enter submit | Tab complete | Ctrl-L clear | /quit exits | {}", base_status, app.url)
        } else {
            base_status
        };
        frame.render_widget(Paragraph::new(help).style(Style::default().fg(Color::DarkGray)), chunks[2]);
    })?;
    Ok(())
}

fn handle_key(app: &mut ChatApp, key: KeyEvent) {
    match (key.code, key.modifiers) {
        (KeyCode::Char('q'), KeyModifiers::CONTROL) => app.should_quit = true,
        (KeyCode::Char('l'), KeyModifiers::CONTROL) => app.clear(),
        (KeyCode::Enter, _) => app.submit(),
        (KeyCode::Tab, _) => app.complete_slash(),
        (KeyCode::Backspace, _) => {
            app.input.pop();
        }
        (KeyCode::Esc, _) => app.status = "Use Ctrl-Q to quit".to_string(),
        (KeyCode::Char(ch), KeyModifiers::NONE) | (KeyCode::Char(ch), KeyModifiers::SHIFT) => {
            app.input.push(ch);
        }
        _ => {}
    }
}
