# Create an R-native Rbebelm agent session

`bebel_r_agent()` is a higher-level layer inspired by R console agents.
It keeps one BebeLM agent, a private tool context, and a small R tool
catalog together so the same object can be driven by a console loop or
by the JSON-RPC server.

## Usage

``` r
bebel_r_agent(
  model,
  system_prompt = NULL,
  tools = NULL,
  env = .GlobalEnv,
  cwd = getwd(),
  allow_eval = TRUE,
  prompt_detail = c("compact", "full"),
  greedy = FALSE,
  max_gen = 512,
  max_context = 4096,
  max_think = 64,
  temperature = 0.8,
  top_k = 50,
  repeat_penalty = 1.1
)
```

## Arguments

- model:

  A `BebelModel` object.

- system_prompt:

  System prompt. `NULL` builds a default prompt including the tool
  catalog.

- tools:

  Tool catalog. Defaults to
  [`bebel_default_r_tools()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_default_r_tools.md).

- env:

  Environment exposed to R tools.

- cwd:

  Working directory for file tools.

- allow_eval:

  Whether to include `r_eval` and `r_plot` tools that execute R code and
  render plots. Defaults to `TRUE`; set `FALSE` to start read-only.

- prompt_detail:

  Tool prompt detail. `"compact"` is faster for console use; `"full"`
  includes descriptions for every argument.

- greedy, max_gen, max_context, max_think, temperature, top_k,
  repeat_penalty:

  Generation options passed to
  [`bebel_agent()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent.md).

## Value

A `bebelRAgent` environment.
