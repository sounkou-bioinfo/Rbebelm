# R tool exposed to BebeLM

R tool exposed to BebeLM

## Usage

``` r
BebelToolSpec(
  name = character(0),
  fun = NULL,
  description = NULL,
  schema = NULL
)
```

## Arguments

- name:

  Tool name exposed to the model and dispatcher.

- fun:

  R function called for matching tool calls.

- description:

  Optional tool description.

- schema:

  Optional JSON-schema-like list or JSON string.
