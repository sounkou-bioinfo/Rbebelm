# Create an Rbebelm agent tool specification

This is a small metadata layer on top of
[`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md).
It keeps a JSON-schema-like parameter specification next to the
executable R function so the same tool catalog can be used by the
console agent and the RPC surface.

## Usage

``` r
bebel_agent_tool(name, description, params = list(), fun)
```

## Arguments

- name:

  Tool name.

- description:

  Short description shown to the model and clients.

- params:

  Named list of parameter specifications. Each entry may contain `type`,
  `description`, `required`, and `enum`.

- fun:

  Function called as `fun(args, context, call)` or any subset of those
  names, following
  [`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md)
  conventions.

## Value

A `bebelAgentTool` object.
