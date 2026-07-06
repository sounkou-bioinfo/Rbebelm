# Drain queued BebeLM async job events

Drain queued BebeLM async job events

## Usage

``` r
bebel_async_events(job, max = NULL)
```

## Arguments

- job:

  A `BebelAsyncJob`.

- max:

  Optional maximum number of queued events to drain.

## Value

A list of generation event lists.
