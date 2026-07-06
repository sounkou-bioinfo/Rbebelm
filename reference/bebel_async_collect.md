# Collect a BebeLM async job result

Collect a BebeLM async job result

## Usage

``` r
bebel_async_collect(job, wait = TRUE)
```

## Arguments

- job:

  A `BebelAsyncJob`.

- wait:

  If `FALSE`, return `NULL` when the job is still running.

## Value

A classed generation result, or `NULL`.
