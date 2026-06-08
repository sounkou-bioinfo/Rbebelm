# Prompt an agent loop

If the loop is idle, this appends the prompt and runs the loop. If the
loop is already active, `streaming_behavior` must be `"steer"` or
`"followUp"`, matching Pi's prompt queue semantics.

## Usage

``` r
bebel_loop_prompt(loop, text, streaming_behavior = NULL)
```

## Arguments

- loop:

  A `bebelAgentLoop`.

- text:

  User prompt text.

- streaming_behavior:

  `NULL`, `"steer"`, or `"followUp"`.

## Value

A loop run result when idle, otherwise invisibly returns `loop`.
