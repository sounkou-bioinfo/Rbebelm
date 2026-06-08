# Run an agent loop

Run an agent loop

## Usage

``` r
bebel_loop_run(loop, prompt = NULL, max_steps = NULL)
```

## Arguments

- loop:

  A `bebelAgentLoop`.

- prompt:

  Optional user prompt to append before running.

- max_steps:

  Optional per-call step cap. Defaults to `loop$policy$max_steps`.

## Value

A `bebelAgentLoopRun` / `bebelAgentRun` result.
