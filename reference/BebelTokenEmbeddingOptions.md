# Token embedding options

Token embedding options

## Usage

``` r
BebelTokenEmbeddingOptions(
  add_bos = logical(0),
  normalize = logical(0),
  token_batch_size = integer(0),
  check_interrupt = logical(0)
)
```

## Arguments

- add_bos:

  Whether to prepend the BOS token before embedding.

- normalize:

  Whether to L2-normalize each token row.

- token_batch_size:

  Number of tokens per Rust batched prefill/matmul call.

- check_interrupt:

  Whether long embedding runs should poll R interrupts between token
  batches.
