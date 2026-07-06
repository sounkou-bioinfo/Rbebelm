# Embed text with pooled BebeLM hidden states

Embed text with pooled BebeLM hidden states

## Usage

``` r
bebel_embed(
  model,
  text,
  add_bos = TRUE,
  normalize = TRUE,
  pooling = c("mean", "last")
)
```

## Arguments

- model:

  A `BebelModel` object.

- text:

  Character vector.

- add_bos:

  Whether to prepend the BOS token before embedding.

- normalize:

  L2-normalize each embedding row.

- pooling:

  Hidden-state pooling strategy: `mean` or `last`.

## Value

A numeric matrix with one row per input text.
