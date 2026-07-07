# Wait for a BebeLM async job

Drains queued stream events on the R thread while polling the job, then
collects the finished result.

## Usage

``` r
bebel_async_wait(
  job,
  on_event = NULL,
  poll_interval = 0.005,
  cancel_on_interrupt = TRUE
)
```

## Arguments

- job:

  A `BebelAsyncJob`.

- on_event:

  Event handler function, named list of event-specific handlers, or
  `NULL`.

- poll_interval:

  Seconds to sleep between polls while the job is pending.

- cancel_on_interrupt:

  Whether an interrupted wait should request Rust-side job cancellation.

## Value

A classed generation result.
