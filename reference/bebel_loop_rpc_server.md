# Serve a generic Rbebelm agent loop over HTTP(S)

This optional SDK surface exposes a backend-agnostic
[`bebel_agent_loop()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_loop.md)
over a transport endpoint with `GET /stream` NDJSON events,
`POST /command` typed commands, and `POST /rpc` JSON-RPC compatibility.
The endpoint may be local HTTP, remote HTTP, or HTTPS/TLS when
`nanonext` is configured with TLS. External frontends such as the native
`rbebelm-tui` binary call the loop protocol and never assume the backend
is a concrete `BebelAgent`.

## Usage

``` r
bebel_loop_rpc_server(loop, url = "http://127.0.0.1:8080", tls = NULL)
```

## Arguments

- loop:

  A `bebelAgentLoop`.

- url:

  URL to listen on, e.g. `"http://127.0.0.1:8080"` or
  `"https://0.0.0.0:8443"`.

- tls:

  Optional TLS configuration from
  [`nanonext::tls_config()`](https://nanonext.r-lib.org/reference/tls_config.html)
  for HTTPS/WSS endpoints.

## Value

A `nanoServer` object from `nanonext`.
