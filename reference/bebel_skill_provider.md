# Create a skill provider

Create a skill provider

## Usage

``` r
bebel_skill_provider(skills = list(), paths = character(), name = "default")
```

## Arguments

- skills:

  `bebelSkill` objects or named character skill bodies.

- paths:

  Skill markdown files or directories to scan. `SKILL.md` files use
  their parent directory name as the skill name.

- name:

  Provider name.

## Value

An `bebelSkillProvider` implementing `BebelSkillProvider`.
