# Generation options

Generation options

## Usage

``` r
BebelGenerationOptions(
  greedy = logical(0),
  check_interrupt = logical(0),
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

- check_interrupt:

  Check for R user interrupts during synchronous generation.

- max_gen, max_context, max_think:

  Optional generation limits.

- temperature, top_k, repeat_penalty:

  Optional sampling settings.
