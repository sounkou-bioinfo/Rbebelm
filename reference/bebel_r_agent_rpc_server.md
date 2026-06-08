# Serve an Rbebelm R agent over JSON-RPC

This optional SDK surface uses `nanonext` to expose the same
`bebelRAgent` object used by the console. JSON parsing/serialization
uses imported `yyjsonr`. It is intentionally small and not an OpenAI
API: clients call JSON-RPC methods such as `turn`, `tools/list`, and
`session/transcript`.

## Usage

``` r
bebel_r_agent_rpc_server(session, url = "http://127.0.0.1:8080")
```

## Arguments

- session:

  A `bebelRAgent`.

- url:

  URL to listen on, e.g. `"http://127.0.0.1:8080"`.

## Value

A `nanoServer` object from `nanonext`.
