# Load a BebeLM GGUF model

Load a BebeLM GGUF model

## Usage

``` r
bebel_model_load(path, num_threads = NULL)
```

## Arguments

- path:

  Path to the GGUF weights file.

- num_threads:

  Optional Rayon global thread-pool size. This can only be set once per
  R process.

## Value

A `BebelModel` object.
