# BebeLM agent backend interface

Backends implement the minimal transcript/generation protocol consumed
by
[`bebel_agent_loop()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_loop.md).

## Usage

``` r
BebelAgentBackend
```

## Format

An object of class `s7contract::s7_interface` (inherits from
`S7_object`) of length 1.
