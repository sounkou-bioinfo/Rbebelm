
<!-- README.md is generated from README.Rmd. Please edit that file. -->

# Rbebelm

<!-- badges: start -->

[![R-CMD-check](https://github.com/sounkou-bioinfo/Rbebelm/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/sounkou-bioinfo/Rbebelm/actions/workflows/R-CMD-check.yaml)
[![R-universe](https://sounkou-bioinfo.r-universe.dev/badges/Rbebelm)](https://sounkou-bioinfo.r-universe.dev/Rbebelm)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

`Rbebelm` is a focused R interface to
[`maximecb/bebelm`](https://github.com/maximecb/bebelm): local CPU
inference for Liquid AI LFM2.5-8B-A1B GGUF weights, exposed through a
small R/Rust API.

The package provides model loading, tokenizer access, pooled embeddings,
bounded generation, persistent agents, BebeLM tool-call parsing, R tool
dispatch, stream events, and Rust-thread async jobs. It does not ship
weights. Set `BEBELM_WEIGHTS_FILE` to a local GGUF path or use the path
directly.

## Install

``` r
install.packages(
  "Rbebelm",
  repos = c("https://sounkou-bioinfo.r-universe.dev", "https://cloud.r-project.org")
)
```

Source installs require Cargo/rustc and GNU make. Native builds compile
scalar and SIMD backend libraries where supported; the runtime
dispatcher selects the best installed backend for the current CPU.

## Load a model

``` r
library(Rbebelm)

model <- bebel_model_load(weights_file, num_threads = 2)
model
#> <BebelModel>
#>   path: /root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf
#>   backend: avx2
rbebelm_backend_features()
#> <Rbebelm backend features>
#>   backend: avx2
#>   target: x86_64-linux
#>   Rust crate: rbebelm_backend 0.1.0
#>   native SIMD feature: yes
#>   compiled features:
#>     AVX2: yes
#>     AVX-512F: no
#>     NEON: no
#>     ARM dotprod: no
#>     wasm simd128: no
#>   model storage: read-only GGUF mmap; repeated loads of the same file share physical pages through the OS page cache
```

The GGUF is memory-mapped read-only by upstream BebeLM. Multiple agents
created from one `BebelModel` share the same in-process `Arc<Model>`.
Separate processes that load the same GGUF can share physical pages
through the operating-system page cache.

Threading is set when the model is loaded. `num_threads` initializes the
process-global Rayon pool once; generation calls use that pool. Async
calls add one Rust worker per job, so total concurrency is controlled by
the model-load thread count and by how many jobs the caller launches.

## Tokenizer and embeddings

``` r
ids <- bebel_tokenize(model, "Bamako", add_bos = FALSE)
ids
#> [1]   42  330 6261
bebel_detokenize(model, ids)
#> [1] "Bamako"

emb <- bebel_embed(model, c(
  mali = "Bamako is the capital of Mali",
  italy = "Rome is the capital of Italy",
  france = "Paris is the capital of France"
))
dim(emb)
#> [1]    3 2048
round(emb[1:2, 1:6], 3)
#>        [,1]   [,2]   [,3]   [,4]  [,5]  [,6]
#> mali  0.005  0.000 -0.018 -0.007 0.012 0.013
#> italy 0.006 -0.004 -0.018 -0.008 0.015 0.014
```

## Generation

``` r
events <- character()
answer <- bebel_generate(
  model,
  "The capital of France is",
  greedy = TRUE,
  max_gen = 8,
  max_think = 0,
  on_event = function(event) events <<- c(events, event$type)
)

answer
#> <BebeLM generation result>
#>   stop: max_new
#>   tokens: 8 generated; 6 prompt
#>   prefill: 14.3 tok/s
#>   decode: 12.63 tok/s
#>   text:
#>  the city of Paris. city of Paris
unique(events)
#> [1] "start"      "text_start" "text_delta" "text_end"   "done"
```

`on_event` is explicit. Pass `NULL` for quiet runs, a function for all
events, or a named list accepted by `bebel_event_handler()`.

``` r
chat <- bebel_chat(
  model,
  "Answer in five words: what does mmap help with?",
  greedy = TRUE,
  max_gen = 24,
  max_think = 0,
  on_event = NULL
)
chat
#> <BebeLM chat result>
#>   stop: eos
#>   tokens: 20 generated; 21 prompt
#>   prefill: 17.7 tok/s
#>   decode: 13.57 tok/s
#>   text:
#> <|tool_call_start|>[constraints(word_count=5, question="what does mmap help with?")]<|tool_call_end|>
```

## Agents

Agents keep transcript tokens, decode caches, and sampling settings. The
loaded weights are shared.

``` r
agent <- bebel_agent(model, greedy = TRUE, max_gen = 16, max_think = 0)
bebel_append_user(agent, "Say exactly: Paris noted.")
turn1 <- bebel_assistant_turn(agent, on_event = NULL)

bebel_append_user(agent, "Say exactly: second turn complete.")
turn2 <- bebel_assistant_turn(agent, on_event = NULL)

turn1
#> <BebeLM assistant turn>
#>   stop: eos
#>   tokens: 10 generated; 15 prompt
#>   prefill: 16.6 tok/s
#>   decode: 13.70 tok/s
#>   text:
#> <
#> </think>
#> Say
#> Say Paris noted.
turn2
#> <BebeLM assistant turn>
#>   stop: eos
#>   tokens: 11 generated; 17 prompt
#>   prefill: 17.7 tok/s
#>   decode: 13.31 tok/s
#>   text:
#> <
#> </Answer>
#> Say second turn complete.
bebel_agent_info(agent)[c("history_tokens", "processed_tokens", "kv_tokens")]
#> $history_tokens
#> [1] 55
#>
#> $processed_tokens
#> [1] 53
#>
#> $kv_tokens
#> [1] 53
substr(bebel_transcript(agent), 1, 160)
#> [1] "<|startoftext|><|im_start|>user\nSay exactly: Paris noted.<|im_end|>\n<|im_start|>assistant\n<\n</think>\nSay  \nSay Paris noted.<|im_end|>\n<|im_start|>user\nSay exact"
```

The direct methods expose the same state:

``` r
length(agent$history())
#> [1] 55
identical(agent$history(), bebel_history(agent))
#> [1] TRUE
agent$clear()[c("history_tokens", "processed_tokens", "kv_tokens")]
#> $history_tokens
#> [1] 0
#>
#> $processed_tokens
#> [1] 0
#>
#> $kv_tokens
#> [1] 0
```

## Tools

Tool declarations are typed S7 objects. Schemas are rendered into the
system turn that BebeLM expects, and parser support is delegated to
upstream BebeLM for the bracketed Pythonic format.

``` r
lookup_capital <- bebel_tool(
  "lookup_capital",
  function(args, context, call) {
    context$calls <- c(context$calls, paste(call$name, args$country))
    c(Mali = "Bamako", Italy = "Rome", France = "Paris")[[args$country]]
  },
  description = "Return a capital city.",
  schema = list(
    properties = list(country = list(type = "string")),
    required = list("country")
  )
)

lookup_capital
#> <BebelToolSpec> lookup_capital
#>   Return a capital city.
bebel_tool_schema_json(lookup_capital)
#> [1] "{\"name\":\"lookup_capital\",\"description\":\"Return a capital city.\",\"parameters\":{\"properties\":{\"country\":{\"type\":\"string\"}},\"required\":[\"country\"],\"type\":\"object\"}}"

ctx <- new.env(parent = emptyenv())
ctx$calls <- character()
call <- bebel_parse_tool_call('[lookup_capital(country="Mali")]')
Rbebelm:::invoke_bebel_tool(lookup_capital, call, ctx)
#> [1] "Bamako"
ctx$calls
#> [1] "lookup_capital Mali"
```

## Async jobs

Async jobs use an aio-style surface: submit work, poll the handle, then
collect the completed `Turn` on the R thread. Several jobs can share one
loaded model; the weights stay shared and model execution is serialized
until the event monitor queue lands. Agent async jobs currently run on a
cloned agent snapshot: the original agent is not mutated.

``` r
job_a <- bebel_generate_async(
  model,
  "The capital of Italy is",
  greedy = TRUE,
  max_gen = 8,
  max_think = 0
)

job_b_agent <- bebel_agent(model, greedy = TRUE, max_gen = 8, max_think = 0)
bebel_append(job_b_agent, "The capital of Mali is")
job_b <- bebel_agent_generate_async(job_b_agent)

bebel_async_poll(job_a)
#> [1] "pending"
async_a <- bebel_async_collect(job_a, wait = TRUE)
async_b <- bebel_async_collect(job_b, wait = TRUE)

async_a
#> <BebeLM generation result>
#>   stop: max_new
#>   tokens: 8 generated; 6 prompt
#>   prefill: 14.5 tok/s
#>   decode: 15.49 tok/s
#>   text:
#>  Rome. city of... ... ... ...
async_b
#> <BebeLM generation result>
#>   stop: max_new
#>   tokens: 8 generated; 6 prompt
#>   prefill: 14.6 tok/s
#>   decode: 15.98 tok/s
#>   text:
#>  the city of Bamako. city of
bebel_agent_info(job_b_agent)[c("history_tokens", "processed_tokens")]
#> $history_tokens
#> [1] 6
#>
#> $processed_tokens
#> [1] 0
```

## Small benchmark table

This is not a model-quality benchmark. It is a reproducible
package-level regression benchmark that records prompt size, generation
size, and throughput for a few deterministic tasks.

``` r
prompts <- c(
  "The capital of Mali is",
  "The capital of Italy is",
  "The capital of Japan is"
)

bench <- lapply(prompts, function(prompt) {
  out <- bebel_generate(model, prompt, greedy = TRUE, max_gen = 8, max_think = 0, on_event = NULL)
  data.frame(
    prompt = prompt,
    text = trimws(out$text),
    prompt_tokens = out$prompt_tokens,
    generated_tokens = out$generated_tokens,
    prefill_tps = out$prefill_tps,
    decode_tps = out$decode_tps,
    stringsAsFactors = FALSE
  )
})

do.call(rbind, bench)
#>                    prompt                              text prompt_tokens
#> 1  The capital of Mali is       the city of Bamako. city of             6
#> 2 The capital of Italy is      Rome. city of... ... ... ...             6
#> 3 The capital of Japan is Tokyo. city. The capital of Japan             6
#>   generated_tokens prefill_tps decode_tps
#> 1                8    14.64088   15.81038
#> 2                8    14.90955   15.73636
#> 3                8    14.59386   15.52764
```
