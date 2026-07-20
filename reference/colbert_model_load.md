# Load a native LFM2.5-ColBERT GGUF model

Loads LiquidAI's retrieval-trained late-interaction encoder. This
profile is distinct from `BebelModel`: it uses bidirectional attention,
learned token-level projections, separate query/document formatting, and
ColBERT MaxSim rather than pooling states from a generation model.

## Usage

``` r
colbert_model_load(path, num_threads = NULL)
```

## Arguments

- path:

  Path to an `LFM2.5-ColBERT-350M` GGUF file. The supported reference
  artifact is `LFM2.5-ColBERT-350M-Q4_K_M.gguf` from
  `LiquidAI/LFM2.5-ColBERT-350M-GGUF`.

- num_threads:

  Optional Rayon global thread-pool size. This can only be set once per
  R process.

## Value

A `ColbertModel` object.
