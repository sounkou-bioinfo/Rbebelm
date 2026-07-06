# Backends and webR

``` r

library(Rbebelm)
```

`Rbebelm` builds native Rust backend libraries and dispatches to the
best one available for the current CPU. Backend selection happens before
model code is loaded.

``` r

rbebelm_cpuid_info()
```

    ## <Rbebelm CPU features>
    ##   x86_64-v3: yes
    ##   x86_64-v4: no
    ##   NEON: no
    ##   ARM dotprod: no
    ##   wasm simd128: no

``` r

rbebelm_backend_info()
```

    ## <Rbebelm backend dispatch>
    ##   mode: dynamic
    ##   requested: auto
    ##   selected: unknown
    ##   loaded: no
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

The feature report includes the compiled SIMD flags and the storage
policy used for GGUF files.

``` r

weights_file <- Sys.getenv("BEBELM_WEIGHTS_FILE", "/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf")
stopifnot(file.exists(weights_file))
model <- bebel_model_load(weights_file, num_threads = 2)
model$info()
```

    ## $path
    ## [1] "/home/runner/work/Rbebelm/Rbebelm/.models/LFM2.5-8B-A1B-Q4_K_M.gguf"
    ## 
    ## $backend
    ## [1] "avx2"
    ## 
    ## $package
    ## [1] "Rbebelm"

In native builds, upstream BebeLM maps the GGUF read-only. Multiple
agents from one model share weights through Rust `Arc<Model>`.

``` r

a <- bebel_agent(model, greedy = TRUE, max_gen = 8, max_think = 0)
b <- bebel_agent(model, greedy = TRUE, max_gen = 8, max_think = 0)

bebel_append(a, "The capital of Mali is")
bebel_append(b, "The capital of Italy is")

bebel_agent_generate(a, on_event = NULL)
```

    ## <BebeLM agent generation>
    ##   stop: max_new
    ##   tokens: 8 generated; 6 prompt
    ##   prefill: 9.6 tok/s
    ##   decode: 11.34 tok/s
    ##   text:
    ##  the city of Bamako. city of

``` r

bebel_agent_generate(b, on_event = NULL)
```

    ## <BebeLM agent generation>
    ##   stop: max_new
    ##   tokens: 8 generated; 6 prompt
    ##   prefill: 11.0 tok/s
    ##   decode: 11.34 tok/s
    ##   text:
    ##  Rome. city of... ... ... ...

For webR, the same R API is the target. The browser runtime must provide
a GGUF in the webR filesystem and enough memory for the selected model.
