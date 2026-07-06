# Render a BebeLM tool schema

Converts an R
[`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md)
declaration into BebeLM's JSON tool schema string for the system
`List of tools: [...]` preamble.

## Usage

``` r
bebel_tool_schema_json(tool)
```

## Arguments

- tool:

  A `BebelToolSpec` object created by
  [`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md).

## Value

A character scalar containing the rendered tool schema.
