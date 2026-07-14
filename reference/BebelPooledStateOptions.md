# Pooled contextual-state options

Pooled contextual-state options

## Usage

``` r
BebelPooledStateOptions(
  add_bos = logical(0),
  normalize = logical(0),
  pooling = character(0),
  token_batch_size = integer(0),
  sequence_batch_size = integer(0),
  check_interrupt = logical(0)
)
```

## Arguments

- add_bos:

  Whether to prepend the model's beginning-of-sequence token.

- normalize:

  Whether to L2-normalize each pooled row.

- pooling:

  Pooling mode: `"weighted_mean"` gives later causal states linearly
  increasing weight, `"mean"` uses equal weights, and `"last"` selects
  the final state.

- token_batch_size:

  Number of tokens per Rust batched prefill/matmul call.

- sequence_batch_size:

  Number of texts per independent-sequence state batch.

- check_interrupt:

  Whether long extraction runs should poll R interrupts between texts
  and token batches.
