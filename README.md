
<!-- README.md is generated from README.Rmd. Please edit that file. -->

# Rbebelm

<!-- badges: start -->

[![R-CMD-check](https://github.com/sounkou-bioinfo/Rbebelm/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/sounkou-bioinfo/Rbebelm/actions/workflows/R-CMD-check.yaml)
[![R-universe](https://sounkou-bioinfo.r-universe.dev/badges/Rbebelm)](https://sounkou-bioinfo.r-universe.dev/Rbebelm)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

`Rbebelm` provides experimental R bindings for upstream
[`maximecb/bebelm`](https://github.com/maximecb/bebelm), a pure-Rust
CPU-only implementation of Liquid AI LFM2.5-8B-A1B inference. The R
package uses [`savvy`](https://github.com/yutannihilation/savvy) for the
R/Rust boundary and an Rsassy-style runtime backend layout for portable
SIMD dispatch.

The package is designed for interactive LLM use: generation streams
tokens to the R console as soon as they are decoded, while the function
still returns the final text, token ids, stop reason, and timing
statistics.

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
CPU/runtime before loading model code.

The model weights are not bundled with the R package. Download the GGUF
weights from the upstream model source documented by
[`bebelm`](https://github.com/maximecb/bebelm), then pass the local path
to `bebel_model_load()`.

## Quick start

The examples below use the GGUF weights at
`/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf`.

``` r
library(Rbebelm)

weights <- "/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf"
model <- bebel_model_load(weights, num_threads = 2)

# Agent-first API: one loaded model can back several cheap conversations.
agent <- bebel_agent(model, greedy = TRUE, max_gen = 48, max_think = 16)

bebel_append_user(agent, "What is the capital of France? Answer briefly.")
turn1 <- bebel_assistant_turn(agent, on_event = NULL)

bebel_append_user(agent, "And Italy?")
turn2 <- bebel_assistant_turn(agent, on_event = NULL)

turn1
#> <BebeLM assistant turn>
#>   stop: eos 
#>   tokens: 26 generated; 19 prompt
#>   prefill: 9.4 tok/s 
#>   decode: 9.50 tok/s 
#>   text:
#> <think>
#> The user asks: "What is the capital of France? Answer briefly."</think>
#> The capital of France is Paris.
turn2
#> <BebeLM assistant turn>
#>   stop: eos 
#>   tokens: 26 generated; 13 prompt
#>   prefill: 9.5 tok/s 
#>   decode: 9.61 tok/s 
#>   text:
#> <think>
#> The user asks: "And Italy?" Possibly they are continuing a conversation</think>
#> The capital of Italy is Rome.
bebel_agent_info(agent)[c("history_tokens", "processed_tokens", "kv_tokens")]
#> $history_tokens
#> [1] 86
#> 
#> $processed_tokens
#> [1] 84
#> 
#> $kv_tokens
#> [1] 84
```

A `BebelAgent` owns the token transcript and decode caches while sharing
the loaded model weights. Later turns only prefill newly appended
tokens. Use `bebel_clear(agent)` to reset the transcript and caches
without reloading the GGUF. For an ellmer-style terminal loop, call
`bebel_live_console(agent)` or `bebel_live_console(model)` in an
interactive R session.

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

One-shot helpers are still available for simple calls. `bebel_chat()`
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
#> <think>
#> The user asks: "In one concise sentence, what does runtime SIMD</think>
#> Runtime SIMD dispatch dynamically selects and executes the most efficient instruction variant for the current hardware at execution time, allowing programs to adapt to varying processor

result
#> <BebeLM chat result>
#>   stop: max_new 
#>   tokens: 48 generated; 22 prompt
#>   prefill: 9.7 tok/s 
#>   decode: 9.80 tok/s 
#>   text:
#> <think>
#> The user asks: "In one concise sentence, what does runtime SIMD</think>
#> Runtime SIMD dispatch dynamically selects and executes the most efficient instruction variant for the current hardware at execution time, allowing programs to adapt to varying processor
```

For one-shot non-chat completion, use `bebel_generate()`:

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
#>  it allows the compiler to generate code that is specific to the target processor architecture, which can lead to better performance. However
raw_result
#> <BebeLM generation result>
#>   stop: max_new 
#>   tokens: 24 generated; 8 prompt
#>   prefill: 9.7 tok/s 
#>   decode: 9.96 tok/s 
#>   text:
#>  it allows the compiler to generate code that is specific to the target processor architecture, which can lead to better performance. However
```

Agents can also be driven at the lower level with raw text or token ids:

``` r
raw_agent <- bebel_agent(model, greedy = TRUE, max_gen = 16, max_think = 0)
bebel_append(raw_agent, "The capital of France is")
raw_turn <- bebel_agent_generate(raw_agent, on_event = NULL)

ids <- bebel_tokenize(model, " and its airport code is", add_bos = FALSE)
bebel_append_tokens(raw_agent, ids)
bebel_history(raw_agent)[1:8]
#> [1] 124894    597   5205    302   3980    355   4741     22
bebel_token_ids()[c("TOKEN_THINK", "TOKEN_TOOL_CALL_START", "TOKEN_TOOL_CALL_END")]
#>           TOKEN_THINK TOKEN_TOOL_CALL_START   TOKEN_TOOL_CALL_END 
#>                124901                124905                124906
raw_turn$text
#> [1] " Paris. city name: france. name: france. city name: paris."
```

Tools can be orchestrated with an Agent-first run loop. The `context`
object is private to R tools and hooks; it is not sent to the model.
This mirrors the RunContext-style use case where tools and observability
hooks share thread/run metadata without exposing it in the prompt.

``` r
ctx <- new.env(parent = emptyenv())
ctx$thread_id <- "thread-001"
ctx$log <- character()

tools <- list(
  lookup_capital = bebel_tool(
    "lookup_capital",
    function(args, context, call) {
      context$log <- c(context$log, paste("tool", call$name, args$country))
      c(France = "Paris", Italy = "Rome")[[args$country]]
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

agent <- bebel_agent(model, max_gen = 128, max_think = 16)
bebel_append_user(agent, "Use tools if needed: what is the capital of Italy?")
run <- bebel_agent_run(agent, tools = tools, context = ctx, hooks = hooks)
run
ctx$log
```

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
#> [1] " be used to update a text field in a UI component."
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
#>     text_delta thinking_delta           done 
#>              4              0              1
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
handler. Use `on_event = NULL` for silent batch-style generation.

## webR / wasm

`Rbebelm` builds the real Rust/savvy backend for webR as a static
`wasm_simd128` backend. The wasm build uses a patched local copy of
upstream BebeLM that avoids native-only `mmap` and Rayon imports on
Emscripten: GGUF files are read from the webR filesystem into memory and
matmul runs serially. If you mount or download a GGUF into the webR
virtual filesystem, `bebel_model_load()` will attempt to load it. Very
large models can still exhaust browser/webR memory; that is a
runtime/resource limit, not an API stub.

## Runtime backend dispatch

`Rbebelm` installs one small R shared library plus separate Rust backend
libraries. The R shared library owns registration and dispatch; model
code lives in the selected backend library. The dispatcher checks CPU/OS
support before loading SIMD backends, so a portable binary can avoid
executing unsupported instructions.

Backend loading is one-shot per R process. If you need to benchmark or
debug a specific backend, call `rbebelm_set_backend()` before the first
native Rbebelm call in a fresh `Rscript` process:

``` r
rbebelm_set_backend("auto")
```

Inspect the current CPU/runtime and selected backend:

``` r
rbebelm_cpuid_info()
#> $cpu_x86_64_v3
#> [1] TRUE
#> 
#> $cpu_x86_64_v4
#> [1] FALSE
#> 
#> $cpu_neon
#> [1] FALSE
#> 
#> $cpu_wasm_simd128
#> [1] FALSE
rbebelm_backend_features()
#> $backend
#> [1] "avx2"
#> 
#> $target_arch
#> [1] "x86_64"
#> 
#> $target_os
#> [1] "linux"
#> 
#> $rust_package
#> [1] "rbebelm_backend"
#> 
#> $rust_package_version
#> [1] "0.0.0"
#> 
#> $native_simd_feature
#> [1] TRUE
#> 
#> $compiled_avx2
#> [1] TRUE
#> 
#> $compiled_avx512f
#> [1] FALSE
#> 
#> $compiled_neon
#> [1] FALSE
#> 
#> $compiled_wasm_simd128
#> [1] FALSE
rbebelm_backend_info()
#> $dispatch_mode
#> [1] "dynamic"
#> 
#> $requested_backend
#> [1] "auto"
#> 
#> $selected_backend
#> [1] "avx2"
#> 
#> $installed_backends
#> [1] "scalar,avx2,avx512"
#> 
#> $supported_backends
#> [1] "scalar,avx2"
#> 
#> $backend_loaded
#> [1] TRUE
```

## Exported API

``` r
ls("package:Rbebelm")
#>  [1] "bebel_agent"              "bebel_agent_configure"   
#>  [3] "bebel_agent_generate"     "bebel_agent_info"        
#>  [5] "bebel_agent_run"          "bebel_append"            
#>  [7] "bebel_append_tokens"      "bebel_append_tool_result"
#>  [9] "bebel_append_user"        "bebel_assistant_turn"    
#> [11] "bebel_chat"               "bebel_clear"             
#> [13] "bebel_console_event"      "bebel_detokenize"        
#> [15] "bebel_event_handler"      "bebel_event_types"       
#> [17] "bebel_generate"           "bebel_history"           
#> [19] "bebel_live_console"       "bebel_model_load"        
#> [21] "bebel_parse_tool_call"    "bebel_token_ids"         
#> [23] "bebel_tokenize"           "bebel_tool"              
#> [25] "bebel_transcript"         "BebelAgent"              
#> [27] "BebelModel"               "rbebelm_backend_features"
#> [29] "rbebelm_backend_info"     "rbebelm_cpuid_info"      
#> [31] "rbebelm_set_backend"
```

Core calls:

- `bebel_model_load(path, num_threads = NULL)`
- `bebel_agent(model, ...)`, `bebel_append_user(agent, message)`,
  `bebel_assistant_turn(agent, ...)`
- `bebel_append(agent, text)`, `bebel_append_tokens(agent, ids)`,
  `bebel_agent_generate(agent, ...)`
- `bebel_tokenize(model, text)`, `bebel_detokenize(model, ids)`,
  `bebel_token_ids()`
- `bebel_live_console(model_or_agent)`
- `bebel_event_types()`
- `bebel_event_handler(text_delta = ..., thinking_delta = ..., tool_call_delta = ..., done = ..., default = ...)`
- `bebel_generate(model, prompt, on_event = bebel_console_event(), check_interrupt = TRUE, ...)`
- `bebel_chat(model, message, on_event = bebel_console_event(), check_interrupt = TRUE, ...)`
- `rbebelm_cpuid_info()`
- `rbebelm_backend_info()`
- `rbebelm_backend_features()`
- `rbebelm_set_backend("auto" | "scalar" | "avx2" | "avx512" | "neon")`

## Development

Common development commands from the repository root:

``` sh
make rd           # regenerate savvy wrappers, dispatch init, NAMESPACE, and man/*.Rd
make rdm          # regenerate README.md from evaluated README.Rmd
make dev-install  # install the package locally from source
make test         # run tinytest tests
make check        # build and run R CMD check --no-manual
make site         # build the pkgdown site
make clean        # remove generated build artifacts
```
