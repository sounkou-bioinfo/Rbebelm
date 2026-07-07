# Embed each token with BebeLM hidden states

Embed each token with BebeLM hidden states

## Usage

``` r
bebel_token_embed(
  model,
  text,
  add_bos = TRUE,
  normalize = TRUE,
  token_batch_size = 512L,
  check_interrupt = TRUE
)
```

## Arguments

- model:

  A `BebelModel` object.

- text:

  Character scalar.

- add_bos:

  Whether to prepend the BOS token before embedding.

- normalize:

  L2-normalize each token row.

- token_batch_size:

  Number of tokens per Rust batched prefill/matmul call.

- check_interrupt:

  Whether long embedding runs should poll R interrupts between token
  batches.

## Value

A `bebelTokenEmbeddings` list with token ids, decoded token strings,
zero-based token indices, and an `n_token x hidden_dim` numeric matrix.
