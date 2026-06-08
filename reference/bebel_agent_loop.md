# Create a stateful BebeLM agent loop

`bebel_agent_loop()` is the UI-independent controller inspired by Pi's
Agent/AgentSession versus InteractiveMode split. It owns lifecycle
state, queues, policy, hooks, and tool dispatch. Consoles, RPC handlers,
and TUIs should consume this loop rather than embedding agent business
logic.

## Usage

``` r
bebel_agent_loop(
  agent,
  tools = list(),
  context = new.env(parent = emptyenv()),
  policy = bebel_loop_policy(),
  hooks = list(),
  extensions = list(),
  session = TRUE,
  parse_tool_call = bebel_parse_tool_calls,
  on_event = NULL,
  check_interrupt = TRUE
)
```

## Arguments

- agent:

  An object implementing `BebelAgentBackend`.

- tools:

  A list of
  [`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md)
  objects or named functions.

- context:

  Private mutable context passed to tools and hooks.

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

- session:

  Session persistence setting. `TRUE` creates an `bebelSession` under
  [`bebel_session_dir()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_dir.md),
  `FALSE`/`NULL` disables persistence, an `bebelSession` reuses that
  store, and a character path opens a JSONL session.

- parse_tool_call:

  Function converting tool-call text into one or more call records.

- on_event:

  Optional event callback or handler list for model stream events.

- check_interrupt:

  Check for Ctrl-C during generation.

## Value

A `bebelAgentLoop` environment.
