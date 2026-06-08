# Agent session storage directory

Returns the directory used for backend-agnostic agent session JSONL
files. By default sessions are stored under
`tools::R_user_dir("Rbebelm", "data")/sessions/<encoded-cwd>/`, inspired
by Pi's per-working-directory session layout. Set `RBEBELM_SESSION_DIR`
or pass `session_dir` to the creation/opening helpers to override it.

## Usage

``` r
bebel_session_dir(cwd = getwd(), session_root = NULL, create = TRUE)
```

## Arguments

- cwd:

  Working directory represented by the session directory.

- session_root:

  Optional root directory. Defaults to
  `Sys.getenv("RBEBELM_SESSION_DIR")` or the package user data
  directory.

- create:

  Create the directory if needed?

## Value

A session directory path.
