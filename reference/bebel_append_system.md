# Append a ChatML system turn to a BebeLM agent transcript

Appends `<|im_start|>system\n...<|im_end|>` framing. BebeLM upstream
does not expose a separate system-prompt channel; this helper provides
the ChatML system-role form for users who want to place an instruction
before user turns.

## Usage

``` r
bebel_append_system(agent, message)
```

## Arguments

- agent:

  A `BebelAgent` object.

- message:

  System instruction text.

## Value

Invisibly returns `agent`.
