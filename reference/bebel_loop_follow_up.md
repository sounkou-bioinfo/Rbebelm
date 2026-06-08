# Queue a follow-up message

Follow-up messages mirror Pi's `followUp()` queue: they are delivered
only when the loop would otherwise stop because there are no tool calls
or steering messages left.

## Usage

``` r
bebel_loop_follow_up(loop, message)
```

## Arguments

- loop:

  A `bebelAgentLoop`.

- message:

  Text to queue.
