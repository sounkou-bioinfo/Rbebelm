# Append an upstream BebeLM system turn to an agent transcript

Delegates ChatML system-turn rendering to upstream BebeLM. When `tools`
are supplied, their schemas are rendered in upstream's
`List of tools: [...]` system-block preamble before `message`.

## Usage

``` r
bebel_append_system(agent, message, tools = NULL)
```

## Arguments

- agent:

  A `BebelAgent` object.

- message:

  System instruction text.

- tools:

  Optional list of
  [`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md)
  objects or named functions to advertise.

## Value

Invisibly returns `agent`.
