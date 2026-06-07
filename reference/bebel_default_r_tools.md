# Built-in R session tools for the Rbebelm agent layer

The default catalog is intentionally small. It exposes read-only file
and R session inspection tools plus optional R evaluation and plot
rendering. These are ordinary R functions and run in the current R
process.

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

  Environment used by `r_objects`, `r_eval`, and `r_plot`.

- cwd:

  Working directory for file and plot tools.

- allow_eval:

  Whether to include the `r_eval` and `r_plot` tools. If `FALSE`,
  code-evaluation tools are not advertised to the model.

- max_chars:

  Maximum characters returned from a single tool.

## Value

A named list of `bebelAgentTool` objects.
