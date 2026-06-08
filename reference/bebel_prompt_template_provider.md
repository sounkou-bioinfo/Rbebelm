# Create a prompt-template provider

Create a prompt-template provider

## Usage

``` r
bebel_prompt_template_provider(
  templates = list(),
  paths = character(),
  name = "default"
)
```

## Arguments

- templates:

  `bebelPromptTemplate` objects or named character templates.

- paths:

  Template files or directories to scan.

- name:

  Provider name.

## Value

An `bebelPromptTemplateProvider` implementing
`BebelPromptTemplateProvider`.
