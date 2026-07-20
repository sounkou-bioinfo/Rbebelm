# Rbebelm

`Rbebelm` provides local pure-Rust CPU inference for three complementary
GGUF models: Liquid AI LFM2.5-8B-A1B through
[`maximecb/bebelm`](https://github.com/maximecb/bebelm), and Google’s
retrieval-trained EmbeddingGemma-300M and LiquidAI’s LFM2.5-ColBERT-350M
through dedicated native encoders.

The package provides model loading, tokenizer access, semantic text
embeddings, trained late-interaction token vectors and MaxSim scoring,
bounded generation, persistent agents, BebeLM tool-call parsing, R tool
dispatch, stream events, and Rust-thread async jobs. It does not ship
weights. Set `BEBELM_WEIGHTS_FILE`, `EMBEDDING_GEMMA_WEIGHTS_FILE`, and
`COLBERT_WEIGHTS_FILE` to local GGUF paths or pass paths directly.
EmbeddingGemma weights are governed by the [Gemma Terms of
Use](https://ai.google.dev/gemma/terms).

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
process-global Rayon pool once; generation and retrieval calls use that
pool. Async calls add one Rust worker per job and can execute
concurrently, so total CPU demand is controlled by the model-load thread
count and by how many jobs the caller launches.

## Tokenizer

``` r

ids <- bebel_tokenize(model, "Bamako", add_bos = FALSE)
ids
#> [1]   42  330 6261
bebel_detokenize(model, ids)
#> [1] "Bamako"
```

## Retrieval-trained EmbeddingGemma

EmbeddingGemma is a separate stateless model handle. The Rust
implementation loads the `gemma-embedding` GGUF directly and runs its
bidirectional encoder, mean pooling, both learned dense projections, and
L2 normalization without linking to llama.cpp, PyTorch, ONNX Runtime, or
the SentencePiece C++ library.

``` r

embedding_model <- embeddinggemma_model_load(
  embedding_weights_file,
  num_threads = bebel_threads
)

query_embedding <- embeddinggemma_embed_query(
  embedding_model,
  "capital of Mali"
)
document_embeddings <- embeddinggemma_embed_document(
  embedding_model,
  c(
    mali = "Bamako is the capital and largest city of Mali.",
    italy = "Rome is the capital city of Italy.",
    desert = "The Sahara is a desert in northern Africa."
  )
)

sort(drop(document_embeddings %*% as.numeric(query_embedding)), decreasing = TRUE)
#>      mali     italy    desert
#> 0.6257073 0.2532762 0.1605835
```

The query and document helpers apply different prompts because that
distinction is part of the model’s training contract. Character vectors
use bounded packed encoder batches while retaining independent positions
and attention boundaries.
[`embeddinggemma_embed()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/embeddinggemma_embed.md)
requires an explicit task for other uses. Set `dimensions` to 512, 256,
or 128 for Matryoshka truncation and re-normalization.

## Late-interaction ColBERT

LFM2.5-ColBERT-350M is a separate, retrieval-trained bidirectional
encoder. It produces 128-dimensional L2-normalized vectors for
individual query and document tokens, then scores a query with ColBERT
MaxSim rather than reducing text to a single pooled vector.

``` r

colbert_model <- colbert_model_load(
  colbert_weights_file,
  num_threads = bebel_threads
)

ranking <- colbert_rank(
  colbert_model,
  "capital of Mali",
  c(
    mali = "Bamako is the capital and largest city of Mali.",
    italy = "Rome is the capital city of Italy.",
    desert = "The Sahara is a desert in northern Africa."
  )
)
ranking
#> <ColBERT MaxSim ranking>
#>     mali    italy   desert
#> 30.60933 29.99548 29.56865

query_vectors <- colbert_encode_query(colbert_model, "capital of Mali")
colbert_embeddings_info(query_vectors)
#> $kind
#> [1] "query"
#>
#> $tokens
#> [1] 32
#>
#> $dimensions
#> [1] 128
```

The encoder owns the model’s published `[Q]` and `[D]` prefixes,
32-query and 512-document limits, punctuation filtering, token-vector L2
normalization, and MaxSim contract.
[`colbert_rank()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/colbert_rank.md)
is exact candidate scoring; use a dedicated late-interaction index for
large corpora. Set `COLBERT_WEIGHTS_FILE` to a local
`LFM2.5-ColBERT-350M` GGUF to execute this example when rendering the
README.

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
#>   prefill: 36.1 tok/s
#>   decode: 37.93 tok/s
#>   text:
#>  the city of Paris. city of Paris
unique(events)
#> [1] "start"      "text_start" "text_delta" "text_end"   "done"
```

`on_event` is explicit. Pass `NULL` for quiet runs, a function for all
events, or a named list accepted by
[`bebel_event_handler()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_event_handler.md).

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
#>   prefill: 49.8 tok/s
#>   decode: 33.88 tok/s
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
#>   prefill: 49.6 tok/s
#>   decode: 33.81 tok/s
#>   text:
#> <
#> </think>
#> Say
#> Say Paris noted.
turn2
#> <BebeLM assistant turn>
#>   stop: eos
#>   tokens: 11 generated; 17 prompt
#>   prefill: 50.2 tok/s
#>   decode: 34.21 tok/s
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
on the R thread, then collect the completed `Turn`.
[`bebel_async_wait()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_async_wait.md)
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
#>   prefill: 23.2 tok/s
#>   decode: 21.22 tok/s
#>   text:
#>  Rome. city of... ... ... ...
async_b
#> <BebeLM generation result>
#>   stop: max_new
#>   tokens: 8 generated; 6 prompt
#>   prefill: 22.8 tok/s
#>   decode: 21.07 tok/s
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
#>   elapsed: 1.038 s
#>   generated throughput: 23.12 tok/s
bench$aggregate
#>   job_count prompt_count repeats concurrency elapsed_seconds
#> 1         3            3       1           2           1.038
#>   total_prompt_tokens total_generated_tokens generated_tps_wall
#> 1                  18                     24           23.12139
#>   generated_tps_decode mean_job_wall_seconds mean_decode_tps
#> 1             24.40489                 0.561        26.47614
bench$jobs[, c("prompt", "generated_tokens", "wall_seconds", "decode_tps", "event_count")]
#>                    prompt generated_tokens wall_seconds decode_tps event_count
#> 1  The capital of Mali is                8        0.661   20.85688          12
#> 2 The capital of Italy is                8        0.647   20.53946          12
#> 3 The capital of Japan is                8        0.375   38.03207          12
```
