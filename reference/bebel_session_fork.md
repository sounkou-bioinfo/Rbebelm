# Fork an agent session file into a new session file

`bebel_session_fork()` copies all non-header entries from an existing
JSONL file. `bebel_session_clone_branch()` copies only the path from the
root to a selected leaf, matching Pi's active-branch clone behavior.

## Usage

``` r
bebel_session_fork(source_path, cwd = getwd(), session_dir = NULL, id = NULL)

bebel_session_clone_branch(
  session,
  leaf_id = bebel_session_leaf_id(session),
  cwd = session$cwd,
  session_dir = session$session_dir,
  id = NULL
)
```

## Arguments

- source_path:

  Source JSONL session file.

- cwd:

  Target working directory for the new session.

- session_dir:

  Optional concrete target session directory.

- id:

  Optional new session id.

- session:

  Source `bebelSession` for branch cloning.

- leaf_id:

  Leaf entry id to clone. Defaults to the source session leaf.

## Value

The opened forked/cloned `bebelSession`.
