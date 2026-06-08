# Define an agent-loop command

Commands are UI-independent loop actions. A TUI or console can render
the command catalog, but execution happens against the `bebelAgentLoop`.

## Usage

``` r
bebel_loop_command(name, fun, description = NULL, usage = NULL)
```

## Arguments

- name:

  Command name without a leading slash.

- fun:

  Function called as `fun(args, loop, context)`.

- description:

  Optional human-readable description.

- usage:

  Optional usage string.

## Value

A `bebelLoopCommand` object.
