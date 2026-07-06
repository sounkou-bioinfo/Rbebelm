# Register extensions on a running loop

Adds one or more extension objects to an existing `bebelAgentLoop`,
rebuilds the loop's tool/command/provider/hook catalogs, and emits
extension/catalog events for frontends. This is normal R environment
mutation, not a core reload command.

## Usage

``` r
bebel_loop_register_extension(loop, extensions, replace = FALSE)
```

## Arguments

- loop:

  A `bebelAgentLoop`.

- extensions:

  A
  [`bebel_extension()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_extension.md)
  object or list of objects implementing `BebelAgentExtension`.

- replace:

  Replace existing extensions with the same manifest name.

## Value

Invisibly returns `loop`.
