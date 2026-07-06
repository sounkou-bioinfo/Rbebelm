# Start a background raw agent generation job

The job runs on a cloned agent snapshot. The original agent's transcript
and decode cache are not mutated, while the model weights are shared.

## Usage

``` r
bebel_agent_generate_async(agent)
```

## Arguments

- agent:

  A `BebelAgent` object.

## Value

A `BebelAsyncJob`.
