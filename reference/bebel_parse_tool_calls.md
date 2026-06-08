# Parse BebeLM tool calls

Delegates Pythonic BebeLM tool-call parsing (`[name(arg='value')]`,
including multiple calls) to upstream BebeLM. JSON call objects and
legacy `name({...})` calls are parsed with imported package `yyjsonr`.

## Usage

``` r
bebel_parse_tool_calls(content)
```

## Arguments

- content:

  Accumulated content between BebeLM tool-call delimiters.

## Value

A list of calls, each with `name`, `arguments`, and `raw`.
