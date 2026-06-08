# Create an agent loop from an R-native agent session

Create an agent loop from an R-native agent session

## Usage

``` r
bebel_r_agent_loop(
  session,
  policy = bebel_loop_policy(),
  hooks = list(),
  extensions = list(),
  agent_session = TRUE,
  parse_tool_call = bebel_parse_tool_calls,
  on_event = NULL,
  check_interrupt = TRUE
)
```

## Arguments

- session:

  A `bebelRAgent` from
  [`bebel_r_agent()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent.md).

- policy:

  A
  [`bebel_loop_policy()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_policy.md)
  object.

- hooks:

  Optional named hooks. Loop hooks may observe `state_change`,
  `queue_update`, `message_start`, `message_end`, `model_event`,
  `tool_request`, `tool_result`, `tool_error`, `tool_denied`,
  `observation`, `command_start`, `command_end`, and `loop_end`.

- extensions:

  Optional list of
  [`bebel_extension()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_extension.md)
  objects.

- agent_session:

  Session persistence setting passed to
  [`bebel_agent_loop()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_loop.md).

- parse_tool_call:

  Function converting tool-call text into one or more call records.

- on_event:

  Optional event callback or handler list for model stream events.

- check_interrupt:

  Check for Ctrl-C during generation.

## Value

A `bebelAgentLoop` environment.
