# Agent construction options

Agent construction options

## Usage

``` r
BebelAgentOptions(
  greedy = logical(0),
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
)
```

## Arguments

- greedy:

  Use deterministic greedy decoding.

- max_gen, max_context, max_think:

  Optional generation limits.

- temperature, top_k, repeat_penalty:

  Optional sampling settings.
