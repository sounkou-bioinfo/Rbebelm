# Getting started

``` r

library(Rbebelm)
weights_file <- Sys.getenv("BEBELM_WEIGHTS_FILE", "/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf")
colbert_weights_file <- Sys.getenv("COLBERT_WEIGHTS_FILE", "")
stopifnot(file.exists(weights_file))
colbert_available <- nzchar(colbert_weights_file) && file.exists(colbert_weights_file)
model <- bebel_model_load(weights_file, num_threads = 2)
```

`Rbebelm` loads local BebeLM generation and ColBERT late-interaction
GGUF profiles, then runs bounded CPU inference from R.

``` r

rbebelm_backend_info()
```

    ## <Rbebelm backend dispatch>
    ##   mode: dynamic
    ##   requested: auto
    ##   selected: avx2
    ##   loaded: yes
    ##   installed: scalar,avx2,avx512
    ##   supported: scalar,avx2

``` r

rbebelm_backend_features()
```

    ## <Rbebelm backend features>
    ##   backend: avx2
    ##   target: x86_64-linux
    ##   Rust crate: rbebelm_backend 0.1.0
    ##   native SIMD feature: yes
    ##   compiled features:
    ##     AVX2: yes
    ##     AVX-512F: no
    ##     NEON: no
    ##     ARM dotprod: no
    ##     wasm simd128: no
    ##   model storage: read-only GGUF mmap; repeated loads of the same file share physical pages through the OS page cache

Tokenization is a direct BebeLM model operation.

``` r

ids <- bebel_tokenize(model, "Bamako", add_bos = FALSE)
ids
```

    ## [1]   42  330 6261

``` r

bebel_detokenize(model, ids)
```

    ## [1] "Bamako"

A real late-interaction retriever uses a distinct retrieval-trained
profile, with query/document token vectors and ColBERT MaxSim scoring.

``` r

colbert <- colbert_model_load(colbert_weights_file, num_threads = 2)
colbert_rank(
  colbert,
  "capital of Mali",
  c(
    mali = "Bamako is the capital of Mali.",
    italy = "Rome is the capital of Italy."
  )
)
```

    ## <ColBERT MaxSim ranking>
    ##     mali    italy 
    ## 30.65593 30.03525

Set `COLBERT_WEIGHTS_FILE` to a local `LFM2.5-ColBERT-350M` GGUF when
building this vignette to execute the late-interaction example.

Generation returns text, token ids, stop reason, and timing statistics.

``` r

out <- bebel_generate(
  model,
  "The capital of France is",
  greedy = TRUE,
  max_gen = 8,
  max_think = 0,
  on_event = NULL
)
out
```

    ## <BebeLM generation result>
    ##   stop: max_new
    ##   tokens: 8 generated; 6 prompt
    ##   prefill: 9.7 tok/s
    ##   decode: 11.83 tok/s
    ##   text:
    ##  the city of Paris. city of Paris

A persistent agent keeps transcript and decode caches across turns while
sharing model weights with every other agent created from the same
`BebelModel`.

``` r

agent <- bebel_agent(model, greedy = TRUE, max_gen = 12, max_think = 0)
bebel_append_user(agent, "Say exactly: Paris noted.")
bebel_assistant_turn(agent, on_event = NULL)
```

    ## <BebeLM assistant turn>
    ##   stop: eos
    ##   tokens: 10 generated; 15 prompt
    ##   prefill: 13.2 tok/s
    ##   decode: 10.53 tok/s
    ##   text:
    ## <
    ## </think>
    ## Say  
    ## Say Paris noted.

``` r

bebel_append_user(agent, "Say exactly: second turn complete.")
bebel_assistant_turn(agent, on_event = NULL)
```

    ## <BebeLM assistant turn>
    ##   stop: eos
    ##   tokens: 11 generated; 17 prompt
    ##   prefill: 13.9 tok/s
    ##   decode: 10.69 tok/s
    ##   text:
    ## <
    ## </Answer>  
    ## Say second turn complete.

``` r

bebel_agent_info(agent)[c("history_tokens", "processed_tokens", "kv_tokens")]
```

    ## $history_tokens
    ## [1] 55
    ## 
    ## $processed_tokens
    ## [1] 53
    ## 
    ## $kv_tokens
    ## [1] 53
