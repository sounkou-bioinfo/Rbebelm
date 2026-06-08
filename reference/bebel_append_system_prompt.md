# Render and append a system prompt to an agent backend

Render and append a system prompt to an agent backend

## Usage

``` r
bebel_append_system_prompt(
  agent,
  provider,
  name = "system",
  data = list(),
  skill_provider = NULL,
  skills = character(),
  tools = NULL
)
```

## Arguments

- agent:

  Object implementing `BebelAgentBackend`.

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

- tools:

  Optional backend-native tool declarations.

## Value

`agent`, invisibly.
