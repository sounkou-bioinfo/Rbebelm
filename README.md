
<!-- README.md is generated from README.Rmd. Please edit that file. -->

# Rbebelm

<!-- badges: start -->

[![R-CMD-check](https://github.com/sounkou-bioinfo/Rbebelm/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/sounkou-bioinfo/Rbebelm/actions/workflows/R-CMD-check.yaml)
[![R-universe](https://sounkou-bioinfo.r-universe.dev/badges/Rbebelm)](https://sounkou-bioinfo.r-universe.dev/Rbebelm)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

`Rbebelm` is both a generic R agent framework and a concrete native
local-model backend.

- The framework layer provides backend-agnostic `S7`/`s7contract`
  interfaces for LLM providers, extensions, skills, prompt templates,
  loop events, frontend/TUI command catalogs, and Pi-inspired
  append-only JSONL session trees.
- The concrete backend wraps upstream
  [`maximecb/bebelm`](https://github.com/maximecb/bebelm), a pure-Rust
  CPU-only implementation of [Liquid AI
  LFM2.5-8B-A1B](https://www.liquid.ai/blog/lfm2-5-8b-a1b) inference.
  The R package uses [`savvy`](https://github.com/yutannihilation/savvy)
  for the R/Rust boundary and a runtime backend layout for portable SIMD
  dispatch.
- The native search layer vendors FFF and exposes persistent fuzzy file
  indexes for agents, consoles, RPC clients, and the standalone `tui/`
  frontend via `bebel_file_finder()` and `bebel_file_search()`.

The intended architecture is loop-first: the agent loop owns lifecycle,
queues, tools, extensions, events, and sessions; consoles, RPC servers,
and the standalone `tui/` module consume that loop over catalogs,
events, and transport endpoints instead of owning agent business logic.
BebeLM is the bundled native provider, not a requirement of the
framework contracts.

## Getting started: choose an entry point

- **Use a local model from R**: install the package, point
  `BEBELM_WEIGHTS_FILE` at a GGUF file, and create a `BebelAgent` with
  `bebel_agent()`.
- **Use the generic framework without a model**: start with [Generic
  agent and frontend/TUI
  framework](#generic-agent-and-frontendtui-framework) and the
  `BebelAgentBackend` contract.
- **Use agent file search**: create a persistent native FFF finder with
  `bebel_file_finder()` and query it with `bebel_file_search()`.
- **Use a terminal frontend**: source installs compile the native
  `rbebelm-tui` binary into the package `bin/` directory; run
  `rbebelm-tui run --weights /path/to/model.gguf`, or set
  `BEBELM_WEIGHTS_FILE` and run bare `rbebelm-tui`.

## Installation

Install from R-universe:

``` r
install.packages(
  "Rbebelm",
  repos = c("https://sounkou-bioinfo.r-universe.dev", "https://cloud.r-project.org")
)
```

R-universe can also publish Linux binaries for this universe. To prefer
those binaries on Linux, use the universe binary repository pattern:

``` r
options(repos = c(
  Rbebelm = sprintf(
    "https://sounkou-bioinfo.r-universe.dev/bin/linux/noble-%s/%s/",
    R.version$arch,
    substr(getRversion(), 1, 3)
  ),
  CRAN = sprintf(
    "https://cran.r-universe.dev/bin/linux/noble-%s/%s/",
    R.version$arch,
    substr(getRversion(), 1, 3)
  )
))
install.packages("Rbebelm")
```

Source installs require Cargo/rustc and GNU make. On Linux, macOS, and
Windows, `Rbebelm` builds separate Rust backend libraries when possible:
scalar, AVX2, and AVX-512 on x86_64; scalar and NEON on arm64. The
dispatcher selects the best installed backend supported by the current
CPU/runtime before loading model code. Scalar x86_64 artifacts are
compiled with an explicit baseline target rather than inheriting
`target-cpu=native`; optimized model and FFF/`neo_frizbee` SIMD paths
are used only through backend selection or runtime feature checks.

The model weights are not bundled with the R package. Download the GGUF
weights from the upstream model source documented by
[`bebelm`](https://github.com/maximecb/bebelm), then pass the local path
to `bebel_model_load()`.

## Local model quick start

Set `BEBELM_WEIGHTS_FILE` to the local GGUF path, or replace `weights`
with an explicit file path. This path exercises the concrete native
BebeLM backend. The README examples are evaluated when a local model
file is available during rendering.

``` r
library(Rbebelm)

weights <- Sys.getenv("BEBELM_WEIGHTS_FILE", "LFM2.5-8B-A1B-Q4_K_M.gguf")
model <- bebel_model_load(weights, num_threads = 2)

# Agent-first API: one loaded model can back several conversations.
agent <- bebel_agent(model, greedy = TRUE, max_gen = 48, max_think = 16)

bebel_append_user(agent, "What is the capital of Mali? Answer briefly.")
turn1 <- bebel_assistant_turn(agent, on_event = NULL)

bebel_append_user(agent, "What about Italy?")
turn2 <- bebel_assistant_turn(agent, on_event = NULL)

turn1
turn2
bebel_agent_info(agent)[c("history_tokens", "processed_tokens", "kv_tokens")]
```

A `BebelAgent` owns the token transcript and decode caches while sharing
the loaded model weights. Later turns only prefill newly appended
tokens. The direct methods `agent$history()`, `agent$transcript()`, and
`agent$clear()` expose the same operations as `bebel_history(agent)`,
`bebel_transcript(agent)`, and `bebel_clear(agent)`.

``` r
length(agent$history())
substr(agent$transcript(), 1, 80)
identical(agent$history(), bebel_history(agent))

reset_info <- agent$clear()
reset_info[c("history_tokens", "processed_tokens", "kv_tokens")]
```

For an interactive terminal loop, call `bebel_live_console(agent)` or
`bebel_live_console(model)` in an R session.

``` r
chat <- bebel_agent(model, max_gen = 256, max_think = 64)
bebel_live_console(chat)
#> ╔══════════════════════════════════════════════════════╗
#> ║  Entering BebeLM live console.                     ║
#> ║  Type /quit or /exit to return to R.               ║
#> ╚══════════════════════════════════════════════════════╝
#> >>> What is BebeLM?
#> <think>
#> The user asks for a brief explanation of BebeLM.
#> </think>
#> BebeLM is a small, CPU-focused local language model runtime written in Rust.
#>
#> >>> Why use the R agent API?
#> The R agent keeps the transcript and decode caches alive across turns while
#> sharing the loaded GGUF weights.
#>
#> >>> /quit
```

You can also create the console directly from a model:

``` r
bebel_live_console(model, max_gen = 256, max_think = 64)
```

Convenience helpers are still available for simple calls. `bebel_chat()`
wraps a single ChatML user/assistant turn:

``` r
# on_event defaults to bebel_console_event(): thinking and text print live.
result <- bebel_chat(
  model,
  "In one concise sentence, what does runtime SIMD dispatch do?",
  greedy = TRUE,
  max_gen = 48,
  max_think = 16,
  on_event = bebel_console_event(),
  check_interrupt = TRUE
)

result
```

For plain text completion, use `bebel_generate()`:

``` r
raw_result <- bebel_generate(
  model,
  "Runtime SIMD dispatch is useful because",
  greedy = TRUE,
  max_gen = 24,
  max_think = 16,
  on_event = bebel_console_event(),
  check_interrupt = TRUE
)
raw_result
```

Use `bebel_append_system()` for an upstream-rendered ChatML system turn.
With no tools, the low-level `bebel_append()` form below is equivalent
apart from being more explicit about the tokens. When `tools` are
supplied, BebeLM renders its `List of tools: [...]` system preamble.

``` r
system_agent <- bebel_agent(model)
bebel_append_system(system_agent, "You are concise.")
bebel_transcript(system_agent)

raw_system_agent <- bebel_agent(model)
bebel_append(raw_system_agent, "<|im_start|>system\nYou are concise.<|im_end|>\n")
identical(bebel_transcript(system_agent), bebel_transcript(raw_system_agent))
```

Agents can also be driven at the lower level with raw text or token ids.

``` r
raw_agent <- bebel_agent(model, greedy = TRUE, max_gen = 16, max_think = 0)
bebel_append(raw_agent, "The capital of Mali is")
raw_turn <- bebel_agent_generate(raw_agent, on_event = NULL)

ids <- bebel_tokenize(model, " and its airport code is", add_bos = FALSE)
bebel_append_tokens(raw_agent, ids)
bebel_history(raw_agent)[1:8]
bebel_token_ids()[c("TOKEN_THINK", "TOKEN_TOOL_CALL_START", "TOKEN_TOOL_CALL_END")]
raw_turn$text
```

Tools can be orchestrated with an Agent run loop. The `context` object
is private to R tools and hooks; it is not sent to the model. A tool is
dispatched only when the model emits a BebeLM tool-call block, so
prompts should describe the available tools and the expected call
format. The prompt below asks directly for the tool-call form so the
example exercises the dispatch path.

``` r
ctx <- new.env(parent = emptyenv())
ctx$thread_id <- "thread-001"
ctx$log <- character()

tools <- list(
  lookup_capital = bebel_tool(
    "lookup_capital",
    function(args, context, call) {
      context$log <- c(context$log, paste("tool", call$name, args$country))
      c(Mali = "Bamako", Italy = "Rome")[[args$country]]
    },
    description = "Return a capital city for a country."
  )
)

hooks <- list(
  tool_request = function(call, context, ...) {
    context$log <- c(context$log, paste("request", call$name))
  },
  tool_result = function(call, result, context, ...) {
    context$log <- c(context$log, paste("result", call$name, result))
  }
)

tool_prompt <- paste(
  "Return exactly this tool call and no other text:",
  "lookup_capital({\"country\":\"Italy\"})"
)

agent <- bebel_agent(model, greedy = TRUE, max_gen = 64, max_think = 0)
bebel_append_user(agent, tool_prompt)
run <- bebel_agent_run(agent, tools = tools, context = ctx, hooks = hooks, max_steps = 2)
run
ctx$log
```

## Generic agent and frontend/TUI framework

This is the model-free framework entry point. The BebeLM bindings are
one implementation of a more generic R agent/frontend framework. The
loop itself is backend-agnostic: it talks to objects that implement the
`BebelAgentBackend` S7/s7contract interface. BebeLM implements that
contract today; other local or remote providers can implement the same
generics later.

The core backend contract is intentionally small:

- `bebel_backend_append_user(agent, message)`
- `bebel_backend_append_system(agent, message, tools = NULL)`
- `bebel_backend_append_tool_result(agent, content)`
- `bebel_backend_assistant_turn(agent, on_event, check_interrupt, stop_on_tool_call)`
- `bebel_backend_info(agent)`, `bebel_backend_transcript(agent)`, and
  `bebel_backend_clear(agent)`

`bebel_agent_loop()` owns policy, queues, event emission, tool dispatch,
and session persistence. A console, RPC server, or the standalone `tui/`
module should consume the loop; it should not own agent logic. The queue
semantics mirror Pi’s vocabulary: `bebel_loop_steer()`,
`bebel_loop_follow_up()`, `steering_mode`, and `follow_up_mode`.

``` r
library(Rbebelm)

store <- bebel_session_create(
  cwd = tempdir(),
  session_dir = file.path(tempdir(), "rbebelm-readme-sessions"),
  name = "README demo"
)

user_id <- bebel_session_append_message(store, "user", "Hello from R")
bebel_session_append_message(
  store,
  "assistant",
  list(list(type = "text", text = "Hello.")),
  provider = "demo",
  model = "demo-model",
  stopReason = "stop"
)
#> [1] "c79780da"

bebel_session_leaf_id(store)
#> <bebelSessionLeafId> c79780da
bebel_session_context(store)$messages
#> [[1]]
#> [[1]]$role
#> [1] "user"
#> 
#> [[1]]$content
#> [1] "Hello from R"
#> 
#> 
#> [[2]]
#> [[2]]$role
#> [1] "assistant"
#> 
#> [[2]]$content
#> [[2]]$content[[1]]
#> [[2]]$content[[1]]$type
#> [1] "text"
#> 
#> [[2]]$content[[1]]$text
#> [1] "Hello."
#> 
#> 
#> 
#> [[2]]$provider
#> [1] "demo"
#> 
#> [[2]]$model
#> [1] "demo-model"
#> 
#> [[2]]$stopReason
#> [1] "stop"
```

Session files are append-only JSONL trees inspired by Pi’s session
format. Each entry has an `id` and `parentId`, so `/tree`, `/fork`, and
`/clone` interfaces can be built without rewriting history. By default,
persisted sessions live under
`tools::R_user_dir("Rbebelm", "data")/sessions/<encoded-cwd>/`; set
`RBEBELM_SESSION_DIR` or pass `session_dir` to override that location.

Extensions are also generic capability bundles. An object implementing
`BebelAgentExtension` contributes a manifest plus optional tools,
commands, hooks, skill providers, prompt-template providers, and UI
metadata. The loop can receive extensions at construction time or later
through explicit R mutation with `bebel_loop_register_extension()` /
`bebel_loop_unregister_extension()`; no core `/reload` command is
needed. Frontends render catalogs and listen for `catalog_changed`
events.

``` r
skills <- bebel_skill_provider(list(
  concise = "Prefer concise, direct answers."
))

prompts <- bebel_prompt_template_provider(list(
  system = "You are {{role}} working in {{place}}."
))

ext <- bebel_extension(
  "readme-demo",
  skill_providers = list(default = skills),
  prompt_template_providers = list(default = prompts),
  commands = list(info = bebel_loop_command("info", function(args, loop, context) {
    bebel_loop_state(loop)
  }))
)

bebel_extension_manifest(ext)
#> $name
#> [1] "readme-demo"
#> 
#> $tools
#> NULL
#> 
#> $commands
#> $commands$info
#> $commands$info$name
#> [1] "info"
#> 
#> $commands$info$description
#> [1] "info"
#> 
#> $commands$info$usage
#> [1] "/info"
#> 
#> 
#> 
#> $hooks
#> NULL
#> 
#> $skill_providers
#> [1] "default"
#> 
#> $prompt_template_providers
#> [1] "default"
#> 
#> $keybindings
#> list()
#> 
#> $widgets
#> list()
#> 
#> $metadata
#> list()

# Runtime registration is explicit R state mutation:
# bebel_loop_register_extension(loop, ext)
# bebel_loop_unregister_extension(loop, "readme-demo")

bebel_system_prompt(
  prompts,
  "system",
  data = list(role = "an R agent", place = "Bamako"),
  skill_provider = skills,
  skills = "concise"
)
#> [1] "You are an R agent working in Bamako.\n\n# Loaded skills\n\n## Skill: concise\n\nPrefer concise, direct answers."
```

See the “Generic agent and frontend framework” vignette for a fake
backend example and the full session-tree/forking API.

## Native FFF fuzzy file search

Rbebelm uses the FFF engine behind `fff-c` as its native fuzzy file
search primitive. A persistent `BebelFileFinder` indexes a project once;
consoles, RPC clients, default file tools, and the standalone `tui/`
frontend can reuse it for low-latency file picking.

``` r
search_root <- tempfile("rbebelm-fff-readme-")
dir.create(file.path(search_root, "src"), recursive = TRUE)
writeLines("demo", file.path(search_root, "src", "bamako_agent.R"))
writeLines("notes", file.path(search_root, "README.md"))

finder <- bebel_file_finder(search_root, watch = FALSE)
bebel_file_search(finder, "agent", limit = 5)
#> <bebelFileSearchResult> 1 rows / 1 matched
#>                path
#>  src/bamako_agent.R
#>                                                        absolute_path
#>  /tmp/RtmpjGFOR0/rbebelm-fff-readme-cffce1d27dbc9/src/bamako_agent.R
#>       file_name git_status size            modified score base_score
#>  bamako_agent.R      clean    5 2026-06-09 23:39:37    74         64
#>      match_type exact_match is_binary
#>  fuzzy_filename       FALSE     FALSE
```

The native FFF dependency is not loaded in webR/wasm; the package still
loads there, and file-search creation reports that native FFF is
unavailable. SIMD is handled with the same care as the BebeLM backend:
Rbebelm builds scalar and optimized native dylibs separately, and
FFF/`neo_frizbee` SIMD kernels are only entered through runtime
CPU-feature checks or the already-selected optimized backend.

## ARF-inspired terminal TUI module

The serious terminal frontend is a native Rust binary compiled as part
of the R package source build and installed under
`system.file("bin", package = "Rbebelm")`. It follows ARF’s separation
of concerns: the Rust binary owns terminal state, key handling, TOML
configuration, and transport client behavior; R owns model loading,
generic agent-loop state, tool execution, sessions, JSON, and the loop
endpoint. The endpoint exposes `GET /stream` NDJSON events,
`POST /command` typed commands, and `POST /rpc` JSON-RPC compatibility.
It can be local HTTP, remote HTTP, or HTTPS/TLS via `nanonext`. The
ergonomic default is a single command: `run` starts an R-owned
`bebelAgentLoop`, waits for readiness, attaches `chat`, and stops the R
host when the TUI exits. `headless`, `stream`, `command`, and `chat`
remain available for split-terminal or remote workflows.

``` r
tui <- system.file("bin/rbebelm-tui", package = "Rbebelm")
system2(tui, "config init")
```

``` sh
TUI="$(Rscript -e 'cat(system.file("bin/rbebelm-tui", package = "Rbebelm"))')"

# One terminal: start R host + attach chat + tear down host on exit.
"$TUI" run --weights /path/to/LFM2.5-8B-A1B-Q4_K_M.gguf

# Or configure the model once and use the bare command.
BEBELM_WEIGHTS_FILE=/path/to/LFM2.5-8B-A1B-Q4_K_M.gguf "$TUI"
```

Pi-like slash commands are handled before model turns. `/quit`, `/exit`,
and `/q` quit the terminal locally. Default R-agent hosts also register
`/help`, `/commands`, `/tools`, `/state`, `/transcript`, `/clear`,
`/r <code>`, and `/allow-eval`, `/no-eval`, `/graphics [device]`,
`/r <code>`, and `/rplot [plot-code]`; press `Tab` after `/` for
completion. Direct `/rplot` works as a user command. Model-side
`r_eval`/`r_plot` are enabled by default for local TUI hosts; use
`--no-eval` at startup or `/no-eval` at runtime to remove them from the
model tool catalog. Use `/graphics auto|native|png|jgd|devout-ascii` to
inspect or change how R plots are handled.

Graphics is a first-class R capability. Rbebelm now has a
graphics-device policy for `r_plot` and `/rplot`: `auto`, `native`,
`png`, optional `jgd`, and optional `devout-ascii` (inspired by Mike
FC/coolbutuseless’ `devout`, which bridges R’s graphics device callbacks
to ordinary R functions). In an interactive R console, `auto` prefers
native R graphics; in headless/TUI contexts it uses PNG unless a jgd
socket is available. PNG artifacts are shown as paths plus portable
braille thumbnails in the TUI. Full-color inline pixel preview still
requires a terminal image backend such as Kitty graphics, iTerm2 inline
images, or sixel; a jgd-compatible JSONL graphics stream is the right
longer-term vector/event renderer boundary, not a TUI-owned R graphics
device.

For split-terminal, remote, automation, or editor integrations, use the
lower level endpoint clients:

``` sh
"$TUI" headless --weights /path/to/LFM2.5-8B-A1B-Q4_K_M.gguf --json
"$TUI" stream --url http://127.0.0.1:8080
"$TUI" command --url http://127.0.0.1:8080 --type catalog --params '{}'
"$TUI" command --url http://127.0.0.1:8080 --type turn \
  --params '{"prompt":"Say hi","max_steps":2}'

# Compatibility/control API only:
"$TUI" rpc --url http://127.0.0.1:8080 --method session/info
```

This replaces in-package TUI placeholders: there is no separate
TUI-owned agent loop, no duplicate tool dispatcher, and no core
`/reload`. Extensions are loaded or registered by R
(`bebel_loop_register_extension()`); frontends refresh their local
keybindings, widgets, palettes, and file watchers when catalogs change.

## R-native agent layer

`bebel_r_agent()` adds a small Corteza-inspired layer on top of the core
model bindings. One session object owns a BebeLM agent, a tool catalog,
a private context environment, and can be driven either from an R
console or from a small JSON-RPC SDK surface.

``` r
r_agent <- bebel_r_agent(
  model,
  allow_eval = TRUE,
  greedy = TRUE,
  max_gen = 96,
  max_think = 16
)
bebel_agent_tool_catalog(r_agent$tools)
```

Interactive console. The `/r` command is a direct R escape hatch into
the same environment used by the agent’s R tools; for example
`/r x <- mtcars` creates an object that `r_objects()` can later see.
Visible `/r` output is capped so large objects do not flood the chat
prompt; assign objects or use summaries such as `/r str(x)` for
inspection. For plots, use `/graphics` to inspect or set the plot device
and `/rplot`, e.g. `/rplot plot(mpg ~ cyl, mtcars)`. Interactive R
consoles can use native graphics; headless/TUI sessions default to PNG
artifacts; `devout-ascii` is available when the optional `devout`
package is installed. The `r_eval` and `r_plot` tools are advertised to
the model by default; set `allow_eval = FALSE` or use `/no-eval` in the
TUI to remove them from the model tool catalog. Direct `/r` and `/rplot`
remain user commands.

``` r
bebel_r_agent_console(r_agent)
```

For a one-call launcher from R, use `bebel_r_agent_start()`. It keeps
the loaded BebeLM model object local to the launcher while still sharing
`.GlobalEnv` with `/r` and the agent’s R tools. The console prints a
compact stats line after each user turn.

``` r
bebel_r_agent_start(Sys.getenv("BEBELM_WEIGHTS_FILE", "LFM2.5-8B-A1B-Q4_K_M.gguf"))
```

The package also installs a small script in `inst/bin`:

``` r
agent_bin <- system.file("bin/rbebelm-agent", package = "Rbebelm")
system2(agent_bin, "--help")
```

From a shell, after installation:

``` sh
"$(Rscript -e 'cat(system.file("bin/rbebelm-agent", package = "Rbebelm"))')" \
  --weights /path/to/LFM2.5-8B-A1B-Q4_K_M.gguf
```

Optional RPC server, using optional `nanonext`; JSON parsing and
serialization use imported `yyjsonr`:

``` r
server <- bebel_r_agent_rpc_server(r_agent, url = "http://127.0.0.1:8080")
server$start()
# ... handle requests ...
server$close()
```

The RPC endpoint accepts `POST /rpc` JSON-RPC calls such as
`tools/list`, `session/info`, `session/transcript`, `session/clear`, and
`turn`.

The same event stream can be consumed programmatically. For example,
collect only answer-text deltas while suppressing console output:

``` r
deltas <- character()
invisible(bebel_generate(
  model,
  "A text delta callback can",
  greedy = TRUE,
  max_gen = 12,
  max_think = 16,
  on_event = bebel_event_handler(
    text_delta = function(event) deltas <<- c(deltas, event$delta)
  )
))
paste0(deltas, collapse = "")
```

You can also pass a named list of event-specific handlers directly:

``` r
counts <- c(text_delta = 0L, thinking_delta = 0L, done = 0L)
invisible(bebel_generate(
  model,
  "An event handler list can",
  greedy = TRUE,
  max_gen = 4,
  max_think = 16,
  on_event = list(
    text_delta = function(event) counts["text_delta"] <<- counts[["text_delta"]] + 1L,
    thinking_delta = function(event) counts["thinking_delta"] <<- counts[["thinking_delta"]] + 1L,
    done = function(event) counts["done"] <<- counts[["done"]] + 1L
  )
))
counts
```

## Interrupts and streaming

Generation checks `R_CheckUserInterrupt()` during prompt prefill and
before every decoded token, wrapped through savvy’s unwind protection so
Ctrl-C does not longjmp through Rust frames. Streaming is event-based
and uses a finite event protocol; `bebel_event_types()` reports the
event enum for this build. The current enum is returned by
`bebel_event_types()` and includes stream lifecycle, thinking blocks,
answer text blocks, tool-list blocks, tool-call blocks, and `done`.
Delta events contain `delta`, `id`, and `index`; control start/end
events include the delimiter token `id` and `marker`; end events contain
accumulated `content`. Console printing is just the default event
handler. Use `on_event = NULL` for silent batch generation.

## webR / wasm

`Rbebelm` builds the real Rust/savvy backend for webR as a static
`wasm_simd128` backend. The wasm build uses a patched local copy of
upstream BebeLM that avoids native-only `mmap` and Rayon imports on
Emscripten: GGUF files are read from the webR filesystem into memory and
matmul runs serially. If you mount or download a GGUF into the webR
virtual filesystem, `bebel_model_load()` will attempt to load it. Very
large models can still exhaust browser/webR memory.

## Runtime backend dispatch

`Rbebelm` installs one small R shared library plus separate Rust backend
libraries. The R shared library owns registration and dispatch; model
code lives in the selected backend library. The dispatcher checks CPU/OS
support before loading SIMD backends, so a portable binary can avoid
executing unsupported instructions.

Backend selection happens once per R process. If you need to benchmark
or debug a specific backend, call `rbebelm_set_backend()` before the
first native Rbebelm call in a fresh `Rscript` process:

``` r
rbebelm_set_backend("auto")
```

Inspect the current CPU/runtime and selected backend:

``` r
rbebelm_cpuid_info()
rbebelm_backend_features()
rbebelm_backend_info()
```

## Development

Common development commands from the repository root. The
`make vignettes` target uses `rawvignette`; install it with
`remotes::install_github("matthewkling/rawvignette")` when editing
`vignettes-raw/`.

``` sh
make rd           # regenerate savvy wrappers, dispatch init, NAMESPACE, and man/*.Rd
make rdm          # regenerate README.md from evaluated README.Rmd
make dev-install  # install the package locally from source
make test         # run tinytest tests
make check        # build and run R CMD check --no-manual
make tui-check    # install, run Rust PTY check, and verify TUI PNG graphics preview
make vignettes    # precompile vignettes-raw/ into vignettes/ with rawvignette
make site         # build the pkgdown site
make clean        # remove generated build artifacts

cd tui && cargo check  # check the standalone ARF-inspired terminal frontend
```

`make tui-check` is the real frontend/device check. It uses a Rust PTY
runner plus optional R packages `nanonext` and `later`. The target
starts a fake Rbebelm loop with the normal `GET /stream` +
`POST /command` protocol, launches the installed `rbebelm-tui` in a
pseudo-terminal, submits `/rplot`, and checks that the TUI renders an
`image/png` artifact plus a braille thumbnail. This gate covers behavior
that `R CMD check` and `cargo check` cannot observe because they do not
run an interactive terminal.
