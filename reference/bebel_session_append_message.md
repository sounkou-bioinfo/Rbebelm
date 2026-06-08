# Append a message entry to an agent session

Append a message entry to an agent session

## Usage

``` r
bebel_session_append_message(session, role, content, message = NULL, ...)
```

## Arguments

- session:

  An `bebelSession`.

- role:

  Message role, e.g. `"user"`, `"assistant"`, or `"toolResult"`.

- content:

  Message content. Strings or lists of content blocks are accepted.

- message:

  Optional complete message object. If supplied, `role`, `content`, and
  `...` are ignored.

- ...:

  Extra message fields such as `provider`, `model`, `usage`,
  `stopReason`, `toolName`, or `details`.

## Value

The appended entry id.
