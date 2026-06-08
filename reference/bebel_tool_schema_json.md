# Render a BebeLM tool schema

Converts an R
[`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md)
declaration into BebeLM's JSON tool schema string for the system
`List of tools: [...]` preamble using `yyjsonr`. This is normally called
by
[`bebel_append_system()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_append_system.md)
when `tools` are supplied.

## Usage

``` r
bebel_tool_schema_json(tool)
```

## Arguments

- tool:

  A `bebelTool` object created by
  [`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md).

## Value

A character scalar containing the rendered tool schema.
