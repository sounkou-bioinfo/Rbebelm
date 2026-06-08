# Append session metadata and extension entries

Append session metadata and extension entries

## Usage

``` r
bebel_session_append_session_info(session, name)

bebel_session_append_custom(session, custom_type, data = NULL)

bebel_session_append_custom_message(
  session,
  custom_type,
  content,
  display = TRUE,
  details = NULL
)
```

## Arguments

- session:

  An `bebelSession`.

- name:

  Session display name.

- custom_type:

  Extension or custom entry type.

- data:

  Extension state data. Custom entries do not enter model context.

- content:

  Custom message content. Custom messages may enter model context.

- display:

  Should a UI render the custom message?

- details:

  Optional extension-specific metadata.

## Value

The appended entry id.
