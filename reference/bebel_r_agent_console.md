# Start an interactive Rbebelm console agent

Start an interactive Rbebelm console agent

## Usage

``` r
bebel_r_agent_console(
  session,
  prompt = "bebel> ",
  max_steps = 4L,
  show_stats = TRUE
)
```

## Arguments

- session:

  A `bebelRAgent`.

- prompt:

  Prompt string.

- max_steps:

  Maximum assistant/tool iterations per user prompt.

- show_stats:

  Whether to print token/timing stats after each turn.

## Value

Invisibly returns `session`.
