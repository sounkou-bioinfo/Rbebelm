# Benchmark async BebeLM generation throughput

Launches deterministic generation jobs in bounded async batches against
one loaded model and records per-job timing, token counts, event counts,
and aggregate throughput.

## Usage

``` r
bebel_benchmark_generation(
  model,
  prompts,
  concurrency = min(length(prompts), 2L),
  repeats = 1L,
  greedy = TRUE,
  max_gen = 64L,
  max_context = NULL,
  max_think = 0L,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL,
  poll_interval = 0.001
)
```

## Arguments

- model:

  A `BebelModel` object.

- prompts:

  Character vector of prompts.

- concurrency:

  Maximum number of async jobs in flight.

- repeats:

  Number of times to repeat the prompt set.

- greedy:

  Use deterministic greedy decoding.

- max_gen, max_context, max_think:

  Optional generation limits.

- temperature, top_k, repeat_penalty:

  Optional sampling settings.

- poll_interval:

  Seconds to sleep between async-job polls.

## Value

A `bebelGenerationBenchmark` list.
