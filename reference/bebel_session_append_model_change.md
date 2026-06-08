# Append model/thinking/compaction/branch metadata

Append model/thinking/compaction/branch metadata

## Usage

``` r
bebel_session_append_model_change(session, provider, model_id)

bebel_session_append_thinking_level_change(session, thinking_level)

bebel_session_append_compaction(
  session,
  summary,
  first_kept_entry_id,
  tokens_before,
  details = NULL,
  from_hook = FALSE
)

bebel_session_append_branch_summary(
  session,
  from_id,
  summary,
  details = NULL,
  from_hook = FALSE
)
```

## Arguments

- session:

  An `bebelSession`.

- provider:

  Provider id.

- model_id:

  Model id.

- thinking_level:

  Thinking/reasoning level.

- summary:

  Summary text.

- first_kept_entry_id:

  First entry kept after compaction.

- tokens_before:

  Number of tokens before compaction.

- details:

  Optional metadata.

- from_hook:

  Was the entry created by an extension hook?

- from_id:

  Branch source entry id.

## Value

The appended entry id.
