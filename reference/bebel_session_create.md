# Create an agent session JSONL store

The store is backend-agnostic. It records framework/session information
and message-shaped data; it does not assume a BebeLM transcript
implementation.

## Usage

``` r
bebel_session_create(
  cwd = getwd(),
  session_dir = NULL,
  id = NULL,
  parent_session = NULL,
  name = NULL,
  persist = TRUE
)
```

## Arguments

- cwd:

  Working directory stored in the session header.

- session_dir:

  Optional concrete directory for the JSONL file. If `NULL`,
  [`bebel_session_dir()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_dir.md)
  is used.

- id:

  Optional session id.

- parent_session:

  Optional parent session file path for forks/clones.

- name:

  Optional display name stored as a `session_info` entry.

- persist:

  If `FALSE`, keep the session in memory only.

## Value

An `bebelSession` object.
