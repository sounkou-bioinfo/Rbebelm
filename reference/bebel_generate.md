# Generate a raw continuation from a prompt

Generate a raw continuation from a prompt

## Usage

``` r
bebel_generate(
  model,
  prompt,
  greedy = FALSE,
  on_event = NULL,
  check_interrupt = TRUE,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL,
  poll_interval = 0.005
)
```

## Arguments

- model:

  A `BebelModel` object.

- prompt:

  Prompt text.

- greedy:

  Use deterministic greedy decoding.

- on_event:

  Event handler function, named list of event-specific handlers, or
  `NULL`. Event types are
  [`bebel_event_types()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_event_types.md).
  Delta events contain `delta`, `id`, and `index`; final events contain
  accumulated `content` or `text`.

- check_interrupt:

  Cancel the underlying async job when the R wait is interrupted.

- max_gen, max_context, max_think:

  Optional generation limits.

- temperature, top_k, repeat_penalty:

  Optional sampling settings.

- poll_interval:

  Seconds to sleep between async-job polls.

## Value

A classed list with generated text, token ids, stop reason, and timing
statistics.
