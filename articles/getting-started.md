# Getting started

``` r

library(Rbebelm)
weights_file <- Sys.getenv("BEBELM_WEIGHTS_FILE", "/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf")
stopifnot(file.exists(weights_file))
model <- bebel_model_load(weights_file, num_threads = 2)
```

`Rbebelm` loads a local BebeLM GGUF, exposes tokenizer and embedding
primitives, and runs bounded CPU generation from R.

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

Tokenization and embeddings are direct model operations.

``` r

ids <- bebel_tokenize(model, "Bamako", add_bos = FALSE)
ids
```

    ## [1]   42  330 6261

``` r

bebel_detokenize(model, ids)
```

    ## [1] "Bamako"

``` r

emb <- bebel_embed(model, c("Mali capital", "Italy capital"))
dim(emb)
```

    ## [1]    2 2048

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
    ##   prefill: 10.2 tok/s
    ##   decode: 11.05 tok/s
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
    ##   prefill: 13.5 tok/s
    ##   decode: 10.01 tok/s
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
    ##   prefill: 14.1 tok/s
    ##   decode: 10.05 tok/s
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
