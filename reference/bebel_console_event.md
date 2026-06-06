# Console event handler for generated text and thinking

Returns an event handler suitable for `on_event`. Thinking blocks are
printed with `<think>` markers, text deltas are printed as they arrive,
and done events add a trailing newline.

## Usage

``` r
bebel_console_event()
```

## Value

A function accepting one generation event list.
