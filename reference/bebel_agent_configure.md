# Configure a BebeLM agent

Configure a BebeLM agent

## Usage

``` r
bebel_agent_configure(
  agent,
  greedy = NULL,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
)
```

## Arguments

- agent:

  A `BebelAgent` object.

- greedy:

  Use deterministic greedy decoding.

- max_gen, max_context, max_think:

  Optional generation limits.

- temperature, top_k, repeat_penalty:

  Optional sampling settings.

## Value

Updated agent info.
