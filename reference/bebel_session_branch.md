# Return the branch from root to a session entry

Return the branch from root to a session entry

## Usage

``` r
bebel_session_branch(session, from_id = bebel_session_leaf_id(session))
```

## Arguments

- session:

  An `bebelSession`.

- from_id:

  Entry id. Defaults to the current leaf.

## Value

A list of session entries in path order.
