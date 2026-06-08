# Define a prompt template

Prompt templates are backend-agnostic named text templates. Rendering is
kept deliberately small and portable: `{{name}}` placeholders are
replaced by values in `data`.

## Usage

``` r
bebel_prompt_template(
  name,
  template,
  description = NULL,
  metadata = list(),
  path = NULL
)
```

## Arguments

- name:

  Template name.

- template:

  Template text.

- description:

  Optional description.

- metadata:

  Optional metadata list.

- path:

  Optional source path.

## Value

An `bebelPromptTemplate` object.
