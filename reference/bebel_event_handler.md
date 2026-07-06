# Build a BebeLM generation event handler

`bebel_event_handler()` creates a single `on_event` handler function
from handlers for individual event types. Current event types are
returned by
[`bebel_event_types()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_event_types.md).

## Usage

``` r
bebel_event_handler(
  start = NULL,
  thinking_start = NULL,
  thinking_delta = NULL,
  thinking_end = NULL,
  text_start = NULL,
  text_delta = NULL,
  text_end = NULL,
  tool_list_start = NULL,
  tool_list_delta = NULL,
  tool_list_end = NULL,
  tool_call_start = NULL,
  tool_call_delta = NULL,
  tool_call_end = NULL,
  done = NULL,
  default = NULL
)
```

## Arguments

- start, thinking_start, thinking_delta, thinking_end, text_start,
  text_delta, text_end:

  Optional functions called for the corresponding stream event.

- tool_list_start, tool_list_delta, tool_list_end:

  Optional handlers for BebeLM tool-list delimiter blocks.

- tool_call_start, tool_call_delta, tool_call_end:

  Optional handlers for BebeLM tool-call delimiter blocks.

- done:

  Function called for the final done event, or `NULL`.

- default:

  Function called for events without a type-specific handler, or `NULL`.

## Value

A function accepting one generation event list.
