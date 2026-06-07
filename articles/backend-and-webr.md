# Backends and webR

`Rbebelm` uses runtime backend dispatch so a portable R package can load
a backend that matches the current platform. The R shared library owns
registration and dispatch; model code lives in Rust backend libraries.

``` r

library(Rbebelm)
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
rbebelm_backend_info()
#> $dispatch_mode
#> [1] "dynamic"
#> 
#> $requested_backend
#> [1] "auto"
#> 
#> $selected_backend
#> [1] "unknown"
#> 
#> $installed_backends
#> [1] "scalar,avx2,avx512"
#> 
#> $supported_backends
#> [1] "scalar,avx2"
#> 
#> $backend_loaded
#> [1] FALSE
```

## Backend selection

Backend loading happens once per R process. If you want to request a
backend, call
[`rbebelm_set_backend()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/rbebelm_set_backend.md)
before the first call that loads backend symbols.

``` r

rbebelm_set_backend("auto")
#> [1] "auto"
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

Supported backend names depend on the platform. Typical native builds
include:

- `scalar`
- `avx2` and `avx512` on x86_64 when built
- `neon` on arm64 when built

If the requested backend is not installed or not supported by the
current CPU, the dispatcher reports an error before model code is
loaded.

## webR

The webR build links a static `wasm_simd128` Rust backend. It uses a
patched local copy of upstream BebeLM for Emscripten:

- GGUF files are read from the webR filesystem into memory instead of
  using native `mmap`.
- Matmul runs serially because native Rayon threading is not used in
  webR.
- [`bebel_model_load()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_model_load.md)
  attempts to load a GGUF path from the webR virtual filesystem.

Very large GGUF files can exhaust browser or webR memory. Use smaller
models or browser/runtime settings appropriate for the target
deployment.

The webR diagnostics report the static backend:

``` r

rbebelm_backend_info()
rbebelm_backend_features()
```
