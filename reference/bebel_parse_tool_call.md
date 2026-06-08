# Parse a single BebeLM tool call block

This compatibility wrapper returns the first call from
[`bebel_parse_tool_calls()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_parse_tool_calls.md).
Prefer
[`bebel_parse_tool_calls()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_parse_tool_calls.md)
when multiple calls may be present.

## Usage

``` r
bebel_parse_tool_call(content)
```

## Arguments

- content:

  Accumulated content between BebeLM tool-call delimiters.

## Value

A list with `name`, `arguments`, and `raw`.
