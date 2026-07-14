# Select the Rbebelm native backend

Must be called before loading a model or querying backend features.

## Usage

``` r
rbebelm_set_backend(backend = "auto")
```

## Arguments

- backend:

  One of `"auto"`, `"scalar"`, `"avx2"`, `"avx512"`, `"neon"`,
  `"dotprod"`, or `"wasm_simd128"`.

## Value

The requested backend name.
