# Queue a steering message

Steering messages mirror Pi's `steer()` queue: they are delivered after
the current assistant/tool turn and before the next model call.

## Usage

``` r
bebel_loop_steer(loop, message)
```

## Arguments

- loop:

  A `bebelAgentLoop`.

- message:

  Text to queue.

## Value

Invisibly returns `loop`.
