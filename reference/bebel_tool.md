# Define a BebeLM R tool

Define a BebeLM R tool

## Usage

``` r
bebel_tool(name, fun, description = NULL, schema = NULL)
```

## Arguments

- name:

  Tool name exposed to the tool dispatcher.

- fun:

  Function to run. It is called as
  `fun(args = ..., context = ..., call = ...)` when it accepts those
  names, otherwise with progressively simpler fallbacks.

- description:

  Optional human-readable description.

- schema:

  Optional JSON-schema-like list or JSON string.

## Value

A `BebelToolSpec` object.
