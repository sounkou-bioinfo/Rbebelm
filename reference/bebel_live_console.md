# Live terminal console for BebeLM chats

Start an interactive terminal chat loop. If `x` is a `BebelModel`, a new
`BebelAgent` is created. If `x` is a `BebelAgent`, its existing
transcript and caches are reused. Type `/quit` or `/exit` to leave the
loop.

## Usage

``` r
bebel_live_console(
  x,
  prompt = ">>> ",
  exit_commands = c("/quit", "/exit"),
  on_event = bebel_console_event(),
  check_interrupt = TRUE,
  greedy = FALSE,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
)
```

## Arguments

- x:

  A `BebelModel` or `BebelAgent`.

- prompt:

  Prompt displayed before reading each user message.

- exit_commands:

  Character vector of commands that exit the console.

- on_event:

  Event handler used for assistant output.

- check_interrupt:

  Check for Ctrl-C during generation.

- greedy:

  Use deterministic greedy decoding.

- max_gen, max_context, max_think:

  Optional generation limits.

- temperature, top_k, repeat_penalty:

  Optional sampling settings.

## Value

Invisibly returns the `BebelAgent` used by the console.
