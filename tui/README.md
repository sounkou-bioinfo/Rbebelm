# rbebelm-tui

`rbebelm-tui` is the ARF-inspired terminal frontend module for Rbebelm. It is built
as a native Rust binary whenever the R package is built from source. R owns agent
state, tools, sessions, model loading, and JSON handling; the TUI owns terminal
rendering, key handling, configuration, and transport client behavior.

This replaces placeholder in-package TUI ideas with a clean frontend boundary:

- **run**: starts an R-owned `bebelAgentLoop`, waits for readiness, attaches the
  terminal chat UI, and stops the R host when the UI exits;
- **headless host**: starts only the R host, similar to `arf headless --json`,
  for split-terminal, remote, or editor-driven workflows;
- **transport client**: consumes `GET /stream` NDJSON events and sends
  `POST /command` typed commands; `/rpc` remains a compatibility/control API;
- **terminal UI**: a minimal `crossterm`/`ratatui` chat frontend that consumes the
  event stream and command endpoint;
- **configuration**: TOML config under the platform config directory, mirroring
  ARF's file-based configuration model.

## Build and installed location

The TUI source lives in `src/rust/src/bin/rbebelm-tui.rs` and is compiled by the
package Makevars. A normal source install builds both the R backend libraries and
the TUI binary:

```sh
R CMD INSTALL .
```

The compiled binary is copied into the installed package `bin/` directory:

```r
tui <- system.file("bin/rbebelm-tui", package = "Rbebelm")
system2(tui, "config path")
```

For direct development checks without a full R install:

```sh
cd src/rust
cargo check --no-default-features --features tui-bin --bin rbebelm-tui
cargo run --no-default-features --features tui-bin --bin rbebelm-tui -- config default
```

## Configuration

```sh
rbebelm-tui config path
rbebelm-tui config init
```

Default location:

- Linux: `~/.config/rbebelm/tui.toml`
- macOS: `~/Library/Application Support/rbebelm/tui.toml`
- Windows: `%APPDATA%\\rbebelm\\tui.toml`

Example:

```toml
[startup]
rscript = "Rscript"
weights = ""
rpc_url = "http://127.0.0.1:8080"
num_threads = 2
max_gen = 256
max_think = 48
max_steps = 4
allow_eval = true
greedy = true

[tui]
title = "Rbebelm"
show_help = true

[keybindings]
submit = "enter"
quit = "ctrl-q"
clear = "ctrl-l"
```

## Default one-terminal run

```sh
rbebelm-tui run --weights /path/to/LFM2.5-8B-A1B-Q4_K_M.gguf
```

Or configure the model through `BEBELM_WEIGHTS_FILE` / `startup.weights` and use
bare `rbebelm-tui`, like `pi` starts interactive mode by default:

```sh
BEBELM_WEIGHTS_FILE=/path/to/LFM2.5-8B-A1B-Q4_K_M.gguf rbebelm-tui
```

`run` starts the R host, waits for readiness JSON, attaches the chat frontend,
and kills the host when the UI exits.

## Start only a headless Rbebelm agent

```sh
rbebelm-tui headless --weights /path/to/LFM2.5-8B-A1B-Q4_K_M.gguf --json
```

The command blocks until interrupted and prints readiness JSON before serving.
It requires the R package plus optional `nanonext` and `later`, because the loop
endpoint is an R-level optional surface. The URL can be `http://127.0.0.1:8080`,
remote HTTP such as `http://0.0.0.0:8080`, or HTTPS/TLS when the R host is
created with `nanonext::tls_config()`. This mirrors ARF's split between a
headless R host and transport clients: the host owns R/model state, while
terminal/editor clients attach to it.

## Use the stream and command clients

```sh
rbebelm-tui stream --url http://127.0.0.1:8080
rbebelm-tui command --url http://127.0.0.1:8080 --type session_info --params '{}'
rbebelm-tui command --url http://127.0.0.1:8080 --type catalog --params '{}'
rbebelm-tui command --url http://127.0.0.1:8080 --type turn \
  --params '{"prompt":"Say hi","max_steps":2}'

# JSON-RPC compatibility/control API:
rbebelm-tui rpc --method session/info --url http://127.0.0.1:8080
```

## Attach the terminal UI

```sh
rbebelm-tui chat --url http://127.0.0.1:8080
```

Keys and slash commands:

- `Enter`: submit the current prompt or slash command
- `Tab`: complete slash commands after `/`
- `Backspace`: edit the prompt
- `Ctrl-L`: clear the local screen
- `Ctrl-Q`, `/quit`, `/exit`, `/q`: quit
- default R-agent commands: `/help`, `/commands`, `/tools`, `/state`,
  `/transcript`, `/clear`, `/allow-eval`, `/no-eval`, `/graphics [device]`,
  `/r <code>`, `/rplot [plot-code]`

Direct `/rplot` is a user command and creates a simple plot when no code is
supplied. Model-side `r_eval` and `r_plot` are enabled by default for local TUI
hosts; use `--no-eval` at startup or `/no-eval` at runtime to remove them from
the model tool catalog. Use `/graphics auto|native|png|jgd|devout-ascii` to
inspect or change plot handling.

The frontend intentionally does not implement tools, model calls, transcript
mutation, extension registration, or session persistence. Those stay in R so
consoles, transport clients, and TUI consumers share one agent semantics.
Extensions can be registered at runtime with `bebel_loop_register_extension()`;
frontends refresh local palettes/widgets when they see `catalog_changed` events.

## Plots

Plots are R-owned. `r_plot` and `/rplot` use the configured R graphics device:
`auto`, `native`, `png`, optional `jgd`, or optional `devout-ascii`. TUI/headless
sessions default to PNG artifacts unless a jgd socket is configured. The TUI
marks PNG output as an `image/png` artifact, shows the path, and renders a
portable braille thumbnail from the PNG bytes so thin base-R axes/points survive
terminal rendering better than plain ASCII. Full-color inline pixel preview still
needs a terminal image protocol backend (Kitty graphics, iTerm2 inline images, or
sixel), while a jgd-compatible graphics stream would be the richer vector/event
renderer boundary. The TUI does not own an R graphics device.

## Testing

Real frontend/device check from the repository root:

```sh
make tui-check
```

This target uses a Rust PTY runner plus optional R packages `nanonext` and
`later`. It installs the current package, starts a fake Rbebelm loop over the
normal `GET /stream` + `POST /command` protocol, launches the installed
`rbebelm-tui` through a pseudo-terminal, submits `/rplot`, and asserts that the
terminal output contains an `image/png` artifact plus a braille thumbnail. Use
`cd src/rust && cargo run --no-default-features --features tui-check --bin rbebelm-tui-check -- --keep-artifacts`
to keep the raw terminal log and generated PNG for debugging.

Non-model command checks after package installation:

```sh
TUI="$(Rscript -e 'cat(system.file("bin/rbebelm-tui", package = "Rbebelm"))')"
"$TUI" config default
"$TUI" config path
```

End-to-end local model test, one terminal:

```sh
"$TUI" run \
  --weights /path/to/LFM2.5-8B-A1B-Q4_K_M.gguf \
  --url http://127.0.0.1:8080
```

Split-terminal endpoint test:

```sh
# terminal 1
"$TUI" headless \
  --weights /path/to/LFM2.5-8B-A1B-Q4_K_M.gguf \
  --url http://127.0.0.1:8080 \
  --json

# terminal 2
"$TUI" stream --url http://127.0.0.1:8080
"$TUI" command --type session_info --url http://127.0.0.1:8080 --params '{}'
"$TUI" command --type turn --url http://127.0.0.1:8080 \
  --params '{"prompt":"Say hello from the TUI check","max_steps":1}'
"$TUI" chat --url http://127.0.0.1:8080
```
