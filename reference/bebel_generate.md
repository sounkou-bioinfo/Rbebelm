# Generate a raw continuation from a prompt

Generate a raw continuation from a prompt

## Usage

``` r
bebel_generate(
  model,
  prompt,
  greedy = FALSE,
  on_event = bebel_console_event(),
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

- prompt:

  Prompt text.

- greedy:

  Use deterministic greedy decoding.

- on_event:

  Event callback, named list of event-specific handlers, or `NULL`.
  Event types are
  [`bebel_event_types()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_event_types.md).
  Delta events contain `delta`, `id`, and `index`; final events contain
  accumulated `content` or `text`. Use
  [`bebel_console_event()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_console_event.md)
  for live console output.

- check_interrupt:

  Check for Ctrl-C during prefill and before every decoded token.

- max_gen, max_context, max_think:

  Optional generation limits.

- temperature, top_k, repeat_penalty:

  Optional sampling settings.

## Value

A classed list with generated text, token ids, stop reason, and timing
statistics.
