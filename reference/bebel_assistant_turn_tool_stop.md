# Open an assistant turn and stop when a tool call closes

This low-level variant mirrors upstream BebeLM's tool driver stop
semantics: generation stops with `stop == "tool_call"` after
`<|tool_call_end|>` so the caller can execute the requested tool(s) and
append one tool-result turn. Most users should prefer
[`bebel_agent_run()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_run.md).

## Usage

``` r
bebel_assistant_turn_tool_stop(
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

A `bebelAssistantTurnResult` list.
