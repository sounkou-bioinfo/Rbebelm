# Embedding options

Embedding options

## Usage

``` r
BebelEmbeddingOptions(
  add_bos = logical(0),
  normalize = logical(0),
  pooling = character(0)
)
```

## Arguments

- add_bos:

  Whether to prepend the BOS token before embedding.

- normalize:

  Whether to L2-normalize each embedding row.

- pooling:

  Hidden-state pooling mode, `"mean"` or `"last"`.
