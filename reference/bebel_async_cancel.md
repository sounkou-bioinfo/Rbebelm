# Cancel a BebeLM async job

Requests cancellation from Rust. A cancelled job stops at the next
generation checkpoint and raises an error when collected.

## Usage

``` r
bebel_async_cancel(job)
```

## Arguments

- job:

  A `BebelAsyncJob`.

## Value

`TRUE` when this call set the cancellation flag for the first time.
