# Run one user turn through an Rbebelm R agent

Run one user turn through an Rbebelm R agent

## Usage

``` r
bebel_r_agent_turn(
  session,
  prompt,
  max_steps = 4L,
  on_event = NULL,
  hooks = list(),
  check_interrupt = TRUE
)
```

## Arguments

- session:

  A `bebelRAgent` from
  [`bebel_r_agent()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent.md).

- prompt:

  User prompt.

- max_steps:

  Maximum assistant/tool iterations.

- on_event:

  Optional BebeLM event callback.

- hooks:

  Optional hooks passed to
  [`bebel_agent_run()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_run.md).

- check_interrupt:

  Check for Ctrl-C during generation.

## Value

A `bebelRAgentTurn` list.
