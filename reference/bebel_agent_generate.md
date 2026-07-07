# Generate a raw continuation from a BebeLM agent transcript

Generate a raw continuation from a BebeLM agent transcript

## Usage

``` r
bebel_agent_generate(agent, on_event = NULL, check_interrupt = TRUE)
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

  Check for R interrupts during synchronous agent generation.

## Value

A classed generation result.
