# Async wait options

Async wait options

## Usage

``` r
BebelAsyncWaitOptions(
  poll_interval = integer(0),
  cancel_on_interrupt = logical(0)
)
```

## Arguments

- poll_interval:

  Seconds to sleep between polls while a job is pending.

- cancel_on_interrupt:

  Whether an interrupted wait should request Rust-side job cancellation.
