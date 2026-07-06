# Parse a single BebeLM tool call block

Parse a single BebeLM tool call block

## Usage

``` r
bebel_parse_tool_call(content)
```

## Arguments

- content:

  Accumulated content between BebeLM tool-call delimiters.

## Value

A list with `name`, `arguments`, and `raw`.
