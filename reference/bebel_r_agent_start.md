# Launch an R-native Rbebelm console from weights

Convenience wrapper for loading a model, creating a
[`bebel_r_agent()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent.md),
and entering
[`bebel_r_agent_console()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent_console.md).
This keeps the loaded model object local to the launcher while the agent
tools and `/r` command share `env`.

## Usage

``` r
bebel_r_agent_start(
  weights = Sys.getenv("BEBELM_WEIGHTS_FILE", "LFM2.5-8B-A1B-Q4_K_M.gguf"),
  num_threads = as.numeric(Sys.getenv("BEBELM_NUM_THREADS", "2")),
  env = .GlobalEnv,
  cwd = getwd(),
  allow_eval = TRUE,
  greedy = TRUE,
  max_gen = as.numeric(Sys.getenv("BEBELM_AGENT_MAX_GEN", "256")),
  max_context = 4096,
  max_think = as.numeric(Sys.getenv("BEBELM_AGENT_MAX_THINK", "48")),
  temperature = 0.8,
  top_k = 50,
  repeat_penalty = 1.1,
  prompt = "bebel> ",
  max_steps = 4L,
  show_stats = TRUE,
  prompt_style = c("compact", "full")
)
```

## Arguments

- weights:

  GGUF weights file. Defaults to `BEBELM_WEIGHTS_FILE`, then
  `"LFM2.5-8B-A1B-Q4_K_M.gguf"` in the working directory.

- num_threads:

  Optional Rayon thread count passed to
  [`bebel_model_load()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_model_load.md).

- env:

  Environment shared by `/r`, `r_objects`, and optional `r_eval`.

- cwd:

  Working directory for file tools.

- allow_eval:

  Whether to include an `r_eval` tool that the model can call.

- greedy, max_gen, max_context, max_think, temperature, top_k,
  repeat_penalty:

  Generation options passed to
  [`bebel_r_agent()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent.md).

- prompt:

  Prompt string for
  [`bebel_r_agent_console()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent_console.md).

- max_steps:

  Maximum assistant/tool iterations per user prompt.

- show_stats:

  Whether to print token/timing stats after each turn.

- prompt_style:

  Tool prompt verbosity passed to
  [`bebel_r_agent()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent.md).

## Value

Invisibly returns the `bebelRAgent` session after the console exits.
