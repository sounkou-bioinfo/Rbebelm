# Create a persistent BebeLM agent

A `BebelAgent` owns an independent token transcript and decode cache
while sharing the loaded model weights. This mirrors upstream
`bebelm::agent::Agent`.

## Usage

``` r
bebel_agent(
  model,
  greedy = FALSE,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
)
```

## Arguments

- model:

  A `BebelModel` object.

- greedy:

  Use deterministic greedy decoding.

- max_gen, max_context, max_think:

  Optional generation limits.

- temperature, top_k, repeat_penalty:

  Optional sampling settings.

## Value

A `BebelAgent` object.
