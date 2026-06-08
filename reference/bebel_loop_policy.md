# Create an Agent-loop policy

Policies configure the UI-independent loop. The queue mode names mirror
Pi's core agent loop: queued steering/follow-up messages are drained
either `"one-at-a-time"` or `"all"`.

## Usage

``` r
bebel_loop_policy(
  max_steps = 8L,
  steering_mode = c("one-at-a-time", "all"),
  follow_up_mode = c("one-at-a-time", "all"),
  before_tool_call = NULL
)
```

## Arguments

- max_steps:

  Maximum assistant/tool iterations per run.

- steering_mode:

  How queued steering messages are drained.

- follow_up_mode:

  How queued follow-up messages are drained.

- before_tool_call:

  Optional function `(call, context, loop)` called before dispatching a
  tool. Return `list(block = TRUE, message = "...")` to block.

## Value

A `bebelLoopPolicy` object.
