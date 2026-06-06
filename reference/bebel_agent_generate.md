# Generate a raw continuation from a BebeLM agent transcript

Generate a raw continuation from a BebeLM agent transcript

## Usage

``` r
bebel_agent_generate(
  agent,
  on_event = bebel_console_event(),
  check_interrupt = TRUE
)
```

## Arguments

- agent:

  A `BebelAgent` object.

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

## Value

A classed generation result.
