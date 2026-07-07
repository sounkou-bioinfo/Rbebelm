# Generation benchmark options

Generation benchmark options

## Usage

``` r
BebelGenerationBenchmarkOptions(
  prompts = character(0),
  concurrency = integer(0),
  repeats = integer(0),
  poll_interval = integer(0)
)
```

## Arguments

- prompts:

  Character vector of prompts.

- concurrency:

  Maximum number of async jobs in flight.

- repeats:

  Number of times to repeat the prompt set.

- poll_interval:

  Seconds to sleep between monitor polls.
