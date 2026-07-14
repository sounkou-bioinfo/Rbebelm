# Extract per-token BebeLM contextual states

Returns the post-final-RMSNorm state for each token in one causal
forward pass. Each state sees only that token and its left context.
These states are useful for inspection and representation-learning
experiments, but the underlying LFM2.5 model has no late-interaction
retrieval objective or trained projection head. Raw MaxSim scores must
not be treated as calibrated relevance scores without task-specific
training and evaluation.

## Usage

``` r
bebel_token_states(
  model,
  text,
  add_bos = FALSE,
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

  Whether to prepend the model's beginning-of-sequence token.

- normalize:

  L2-normalize each token-state row.

- token_batch_size:

  Number of tokens per Rust batched prefill/matmul call.

- check_interrupt:

  Whether long extraction runs should poll R interrupts between token
  batches.

## Value

A `bebelTokenStates` list with token ids, decoded token strings,
zero-based token indices, an `n_token x hidden_dim` numeric `states`
matrix, and extraction metadata in `state_info`.
