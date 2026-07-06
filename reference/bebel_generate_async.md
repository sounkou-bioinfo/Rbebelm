# Start a background raw generation job

Async jobs run BebeLM generation on Rust worker threads and reuse the
loaded model weights. They are polled with
[`bebel_async_poll()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_async_poll.md)
and collected with
[`bebel_async_collect()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_async_collect.md).

## Usage

``` r
bebel_generate_async(
  model,
  prompt,
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

- prompt:

  Prompt text.

- greedy:

  Use deterministic greedy decoding.

- max_gen, max_context, max_think:

  Optional generation limits.

- temperature, top_k, repeat_penalty:

  Optional sampling settings.

## Value

A `BebelAsyncJob`.
