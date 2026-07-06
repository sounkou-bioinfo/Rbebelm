# Generate a single ChatML assistant reply

Generate a single ChatML assistant reply

## Usage

``` r
bebel_chat(
  model,
  message,
  greedy = FALSE,
  on_event = NULL,
  check_interrupt = TRUE,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
)
```

## Arguments

- model:

  A `BebelModel` object.

- message:

  User message.

- greedy:

  Use deterministic greedy decoding.

- on_event:

  Event handler function, named list of event-specific handlers, or
  `NULL`. Event types are
  [`bebel_event_types()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_event_types.md).
  Delta events contain `delta`, `id`, and `index`; final events contain
  accumulated `content` or `text`.

- check_interrupt:

  Check for Ctrl-C during prefill and before every decoded token.

- max_gen, max_context, max_think:

  Optional generation limits.

- temperature, top_k, repeat_penalty:

  Optional sampling settings.

## Value

A classed generation result.
