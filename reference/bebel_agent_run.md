# Run a BebeLM agent with R tool dispatch

This is an Agent-first orchestration loop. It observes `tool_call_end`
events, parses tool calls, invokes matching R tools with private
`context`, appends tool results to the agent transcript, and continues
generation.

## Usage

``` r
bebel_agent_run(
  agent,
  tools = list(),
  context = new.env(parent = emptyenv()),
  hooks = list(),
  parse_tool_call = bebel_parse_tool_calls,
  max_steps = 4,
  on_event = NULL,
  check_interrupt = TRUE
)
```

## Arguments

- agent:

  A `BebelAgent` object.

- tools:

  A list of
  [`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md)
  objects or named functions.

- context:

  Private run context passed to tools and hooks but not appended to the
  model transcript.

- hooks:

  Optional named list of hooks: `turn_start`, `event`, `tool_request`,
  `tool_result`, `tool_error`, `turn_end`.

- parse_tool_call:

  Function converting tool-call content to either one
  `list(name, arguments, raw)` or a list of such calls.

- max_steps:

  Maximum assistant/tool iterations.

- on_event:

  Optional event handler function or named handler list for model
  events.

- check_interrupt:

  Check for Ctrl-C during generation.

## Value

A `bebelAgentRun` list with turns, tool calls, and final agent info.
