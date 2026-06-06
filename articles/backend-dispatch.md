# Backend dispatch

`Rbebelm` follows an Rsassy-style layout: one small R shared library
owns the R registration and dispatcher, while Rust model code is
compiled into backend libraries. The dispatcher checks CPU support
before loading a SIMD backend.

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

Explicit backend selection must happen before loading a model or
querying backend features:

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

The backend choice is process-global. Restart R if you need to benchmark
another backend in the same session after one has already been loaded.
