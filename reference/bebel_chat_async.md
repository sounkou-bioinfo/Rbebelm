# Start a background ChatML assistant reply job

Start a background ChatML assistant reply job

## Usage

``` r
bebel_chat_async(
  model,
  message,
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

- message:

  User message.

- greedy:

  Use deterministic greedy decoding.

- max_gen, max_context, max_think:

  Optional generation limits.

- temperature, top_k, repeat_penalty:

  Optional sampling settings.

## Value

A `BebelAsyncJob`.
