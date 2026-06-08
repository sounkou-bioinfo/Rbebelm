# Run one assistant turn on an agent backend

Run one assistant turn on an agent backend

## Usage

``` r
bebel_backend_assistant_turn(
  agent,
  on_event = NULL,
  check_interrupt = TRUE,
  stop_on_tool_call = FALSE
)
```

## Arguments

- agent:

  An object implementing `BebelAgentBackend`.

- on_event:

  Optional stream event callback.

- check_interrupt:

  Check for Ctrl-C during generation.

- stop_on_tool_call:

  Stop after a tool-call delimiter when supported.
