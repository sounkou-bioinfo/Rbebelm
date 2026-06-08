# Compose a system prompt from a prompt template and optional skills

Compose a system prompt from a prompt template and optional skills

## Usage

``` r
bebel_system_prompt(
  provider,
  name = "system",
  data = list(),
  skill_provider = NULL,
  skills = character()
)
```

## Arguments

- provider:

  Object implementing `BebelPromptTemplateProvider`.

- name:

  Prompt template name.

- data:

  Template data.

- skill_provider:

  Optional object implementing `BebelSkillProvider`.

- skills:

  Character vector of skill names to append.

## Value

Rendered system prompt text.
