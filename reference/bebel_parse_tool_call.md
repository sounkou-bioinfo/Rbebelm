# Parse a BebeLM tool call block

The default parser accepts JSON objects such as
`{\"name\": \"tool\", \"arguments\": {...}}` when `jsonlite` is
installed, simple `name({...})` calls, and bracketed BebeLM calls such
as `[name(key=\"value\")]`. Pass a custom parser to
[`bebel_agent_run()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_run.md)
for model- or prompt-specific formats.

## Usage

``` r
bebel_parse_tool_call(content)
```

## Arguments

- content:

  Accumulated content between BebeLM tool-call delimiters.

## Value

A list with `name`, `arguments`, and `raw`.
