# Extract pooled BebeLM contextual states

Runs the causal LFM2.5 model over each input, applies the model's final
output RMSNorm to every token state, and pools those states.
`"weighted_mean"` implements the position-weighted pooling baseline
introduced for GPT sentence representations by Muennighoff (2022)
<https://arxiv.org/abs/2202.08904>.

## Usage

``` r
bebel_pooled_states(
  model,
  text,
  add_bos = TRUE,
  normalize = TRUE,
  pooling = c("weighted_mean", "mean", "last"),
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

  Whether to prepend the model's beginning-of-sequence token.

- normalize:

  L2-normalize each pooled row.

- pooling:

  Pooling strategy. `"weighted_mean"` weights token positions
  `1, ..., n`, `"mean"` uses equal weights, and `"last"` selects the
  final contextual state.

- token_batch_size:

  Number of tokens per Rust batched prefill/matmul call.

- sequence_batch_size:

  Number of texts per independent-sequence state batch.

- check_interrupt:

  Whether long extraction runs should poll R interrupts between texts
  and token batches.

## Value

A `bebelPooledStates` numeric matrix with one row per input text and a
`state_info` attribute describing the extraction contract.

## Details

These are features from a text-generation model, not embeddings from a
model trained for semantic similarity or retrieval. Cosine similarity is
therefore uncalibrated and must be evaluated for the intended task. The
same limitation applies if these vectors are used in a dense index.
