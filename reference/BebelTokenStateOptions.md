# Token contextual-state options

Token contextual-state options

## Usage

``` r
BebelTokenStateOptions(
  add_bos = logical(0),
  normalize = logical(0),
  token_batch_size = integer(0),
  check_interrupt = logical(0)
)
```

## Arguments

- add_bos:

  Whether to prepend the model's beginning-of-sequence token.

- normalize:

  Whether to L2-normalize each token-state row.

- token_batch_size:

  Number of tokens per Rust batched prefill/matmul call.

- check_interrupt:

  Whether long extraction runs should poll R interrupts between token
  batches.
