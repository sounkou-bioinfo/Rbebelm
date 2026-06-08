# Define an agent-loop extension

Extensions contribute tools, commands, hooks, and optional UI metadata
to the agent loop. They are registered into
[`bebel_agent_loop()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_loop.md)
and are deliberately UI-independent: a future Rust TUI can consume the
same command/metadata catalog without owning business logic.

## Usage

``` r
bebel_extension(
  name,
  tools = list(),
  commands = list(),
  hooks = list(),
  skill_providers = list(),
  prompt_template_providers = list(),
  keybindings = list(),
  widgets = list(),
  metadata = list()
)
```

## Arguments

- name:

  Extension name.

- tools:

  Optional list of
  [`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md)
  objects or named functions.

- commands:

  Optional list of
  [`bebel_loop_command()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_command.md)
  objects or named functions.

- hooks:

  Optional named hook list.

- skill_providers:

  Optional named list of objects implementing `BebelSkillProvider`.

- prompt_template_providers:

  Optional named list of objects implementing
  `BebelPromptTemplateProvider`.

- keybindings:

  Optional metadata for TUI consumers.

- widgets:

  Optional metadata for TUI consumers.

- metadata:

  Optional extension metadata.

## Value

A `bebelExtension` object.
