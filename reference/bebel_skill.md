# Define a framework skill

A skill is reusable instruction/context text plus metadata. Skill
providers list and load skills; the loop or prompt-composition layer
decides when to include them.

## Usage

``` r
bebel_skill(name, content, description = NULL, metadata = list(), path = NULL)
```

## Arguments

- name:

  Skill name.

- content:

  Skill content.

- description:

  Optional description.

- metadata:

  Optional metadata list.

- path:

  Optional source path.

## Value

An `bebelSkill` object.
