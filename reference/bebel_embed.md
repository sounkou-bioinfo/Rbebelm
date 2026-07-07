# Embed text with pooled BebeLM hidden states

Embed text with pooled BebeLM hidden states

## Usage

``` r
bebel_embed(
  model,
  text,
  add_bos = TRUE,
  normalize = TRUE,
  pooling = c("mean", "last"),
  token_batch_size = 512L,
  sequence_batch_size = 64L,
  check_interrupt = TRUE
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

- token_batch_size:

  Number of tokens per Rust batched prefill/matmul call.

- sequence_batch_size:

  Number of texts per independent-sequence embedding batch.

- check_interrupt:

  Whether long embedding runs should poll R interrupts between texts and
  token batches.

## Value

A numeric matrix with one row per input text.
