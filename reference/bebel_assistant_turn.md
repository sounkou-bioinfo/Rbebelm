# Generate and close an assistant ChatML turn from a BebeLM agent

Generate and close an assistant ChatML turn from a BebeLM agent

## Usage

``` r
bebel_assistant_turn(agent, on_event = NULL, check_interrupt = TRUE)
```

## Arguments

- agent:

  A `BebelAgent` object.

- on_event:

  Event handler function, named list of event-specific handlers, or
  `NULL`. Event types are
  [`bebel_event_types()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_event_types.md).
  Delta events contain `delta`, `id`, and `index`; final events contain
  accumulated `content` or `text`.

- check_interrupt:

  Check for Ctrl-C during prefill and before every decoded token.

## Value

A classed generation result.
