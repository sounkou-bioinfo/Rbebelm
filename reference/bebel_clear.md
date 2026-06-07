# Clear a BebeLM agent transcript and caches

Clears the conversation state while keeping the loaded model weights and
the agent's generation configuration. This is the helper form of
`agent$clear()`.

## Usage

``` r
bebel_clear(agent)
```

## Arguments

- agent:

  A `BebelAgent` object.

## Value

Updated agent info.
