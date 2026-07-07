
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

model <- bebel_model_load(weights_file, num_threads = bebel_threads)
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
Async jobs created from that model also share those weights while
keeping independent caches. Separate processes that load the same GGUF
can share physical pages through the operating-system page cache.

Threading is set when the model is loaded. `num_threads` initializes the
process-global Rayon pool once; generation and embedding calls use that
pool. Async calls add one Rust worker per job and can execute
concurrently, so total CPU demand is controlled by the model-load thread
count and by how many jobs the caller launches.

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

token_emb <- bebel_token_embed(model, "short stature", add_bos = FALSE)
token_emb
#> <BebeLM token embeddings>
#>   tokens: 3
#>   dimensions: 2048
#>   normalized: TRUE
data.frame(
  token_index = token_emb$token_index,
  token_id = token_emb$ids,
  token = token_emb$tokens
)
#>   token_index token_id token
#> 1           0    24629 short
#> 2           1      377    st
#> 3           2     1239 ature
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
#>   prefill: 29.5 tok/s
#>   decode: 31.65 tok/s
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
#> <BebeLM generation result>
#>   stop: eos
#>   tokens: 20 generated; 21 prompt
#>   prefill: 34.8 tok/s
#>   decode: 27.39 tok/s
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
#>   prefill: 34.3 tok/s
#>   decode: 29.77 tok/s
#>   text:
#> <
#> </think>
#> Say
#> Say Paris noted.
turn2
#> <BebeLM assistant turn>
#>   stop: eos
#>   tokens: 11 generated; 17 prompt
#>   prefill: 35.3 tok/s
#>   decode: 27.06 tok/s
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

Async jobs use an aio-style surface: submit work, monitor queued events
on the R thread, then collect the completed `Turn`. `bebel_async_wait()`
is the blocking monitor used by model-level sync helpers, so stream
callbacks always run on the R thread. Several jobs can share one loaded
model; the weights stay shared and execution can overlap. Agent async
jobs run on a cloned agent snapshot: the original agent is not mutated.

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

event_types_a <- character()
async_a <- bebel_async_wait(
  job_a,
  on_event = function(event) event_types_a <<- c(event_types_a, event$type)
)
async_b <- bebel_async_collect(job_b, wait = TRUE)

unique(event_types_a)
#> [1] "start"      "text_start" "text_delta" "text_end"   "done"
async_a
#> <BebeLM generation result>
#>   stop: max_new
#>   tokens: 8 generated; 6 prompt
#>   prefill: 17.9 tok/s
#>   decode: 17.56 tok/s
#>   text:
#>  Rome. city of... ... ... ...
async_b
#> <BebeLM generation result>
#>   stop: max_new
#>   tokens: 8 generated; 6 prompt
#>   prefill: 16.9 tok/s
#>   decode: 17.82 tok/s
#>   text:
#>  the city of Bamako. city of
bebel_agent_info(job_b_agent)[c("history_tokens", "processed_tokens")]
#> $history_tokens
#> [1] 6
#>
#> $processed_tokens
#> [1] 0
```

## Generation benchmark

The generation benchmark uses bounded async batches against one loaded
model. It records per-job timings, token counts, event counts, and
aggregate throughput for reproducible CPU comparisons.

``` r
prompts <- c(
  "The capital of Mali is",
  "The capital of Italy is",
  "The capital of Japan is"
)

bench <- bebel_benchmark_generation(
  model,
  prompts,
  concurrency = min(length(prompts), 2L),
  repeats = 1L,
  greedy = TRUE,
  max_gen = 8,
  max_think = 0
)

bench
#> <BebeLM generation benchmark>
#>   jobs: 3
#>   concurrency: 2
#>   elapsed: 1.313 s
#>   generated throughput: 18.28 tok/s
bench$aggregate
#>   job_count prompt_count repeats concurrency elapsed_seconds
#> 1         3            3       1           2           1.313
#>   total_prompt_tokens total_generated_tokens generated_tps_wall
#> 1                  18                     24           18.27875
#>   generated_tps_decode mean_job_wall_seconds mean_decode_tps
#> 1             20.11324             0.7123333         21.7817
bench$jobs[, c("prompt", "generated_tokens", "wall_seconds", "decode_tps", "event_count")]
#>                    prompt generated_tokens wall_seconds decode_tps event_count
#> 1  The capital of Mali is                8        0.838   17.07711          12
#> 2 The capital of Italy is                8        0.828   17.08585          12
#> 3 The capital of Japan is                8        0.471   31.18214          12
```
