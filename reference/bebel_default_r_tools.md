# Built-in R session tools for the Rbebelm agent layer

The default catalog is intentionally small. It exposes read-only file
and R session inspection tools plus optional R evaluation. These are
ordinary R functions and run in the current R process.

## Usage

``` r
bebel_default_r_tools(
  env = .GlobalEnv,
  cwd = getwd(),
  allow_eval = FALSE,
  max_chars = 4000L
)
```

## Arguments

- env:

  Environment used by `r_objects` and `r_eval`.

- cwd:

  Working directory for file tools.

- allow_eval:

  Whether to include the `r_eval` tool. If `FALSE`, `r_eval` is not
  advertised to the model.

- max_chars:

  Maximum characters returned from a single tool.

## Value

A named list of `bebelAgentTool` objects.
