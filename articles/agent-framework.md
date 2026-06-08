# Generic agent and frontend framework

`Rbebelm` is intentionally two things at once:

1.  A generic, backend-agnostic R agent/frontend framework that can be
    implemented by BebeLM, another local model, or a remote provider.
2.  A concrete native BebeLM backend for local GGUF inference.

The framework layer is deliberately small and interface-driven. The loop
owns agent lifecycle, queues, events, tool dispatch, extension
registration, and JSONL session persistence. Frontends such as a
console, RPC server, or future Rust TUI consume the same loop instead of
reimplementing or owning agent logic.

## Backend contract

An LLM provider implements the `BebelAgentBackend` interface from
`s7contract` by providing S7 methods for these generics:

- `bebel_backend_append_user(agent, message)`
- `bebel_backend_append_system(agent, message, tools = NULL)`
- `bebel_backend_append_tool_result(agent, content)`
- `bebel_backend_assistant_turn(agent, on_event, check_interrupt, stop_on_tool_call)`
- `bebel_backend_info(agent)`
- `bebel_backend_transcript(agent)`
- `bebel_backend_clear(agent)`

BebeLM implements this contract for `BebelAgent`. The following fake
backend is useful for tests and demonstrates that
[`bebel_agent_loop()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_loop.md)
does not require a BebeLM object.

``` r

library(Rbebelm)

FakeBebelAgentBackendS3 <- S7::new_S3_class("fakeBebelAgentBackendVignette")

S7::method(bebel_backend_append_user, FakeBebelAgentBackendS3) <- function(agent, message) {
  agent$user <- c(agent$user, message)
  agent
}

S7::method(bebel_backend_append_system, FakeBebelAgentBackendS3) <- function(agent, message, tools = NULL) {
  agent$system <- c(agent$system, message)
  agent
}

S7::method(bebel_backend_append_tool_result, FakeBebelAgentBackendS3) <- function(agent, content) {
  agent$tool <- c(agent$tool, content)
  agent
}

S7::method(bebel_backend_assistant_turn, FakeBebelAgentBackendS3) <- function(
  agent,
  on_event = NULL,
  check_interrupt = TRUE,
  stop_on_tool_call = FALSE
) {
  if (!is.null(on_event)) on_event(list(type = "text_delta", delta = "fake reply"))
  list(text = "fake reply", tokens = 2L, stop = "stop")
}

S7::method(bebel_backend_info, FakeBebelAgentBackendS3) <- function(agent) {
  list(provider = "fake", model = "fake-model")
}

S7::method(bebel_backend_transcript, FakeBebelAgentBackendS3) <- function(agent) {
  paste(c(agent$system, agent$user, agent$tool), collapse = "\n")
}

S7::method(bebel_backend_clear, FakeBebelAgentBackendS3) <- function(agent) {
  agent$user <- character()
  agent$tool <- character()
  agent
}

backend <- structure(new.env(parent = emptyenv()), class = "fakeBebelAgentBackendVignette")
backend$user <- character()
backend$system <- character()
backend$tool <- character()
```

## Loop and frontend ownership

[`bebel_agent_loop()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_loop.md)
is the UI-independent controller. It accepts any `BebelAgentBackend`,
optional tools, hooks, extensions, and a persistence setting. The queue
vocabulary follows Pi:

- [`bebel_loop_steer()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_steer.md)
  adds steering messages.
- [`bebel_loop_follow_up()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_follow_up.md)
  adds follow-up messages.
- `bebel_loop_policy(steering_mode = ..., follow_up_mode = ...)`
  controls whether queued messages are drained one-at-a-time or all at
  once.

``` r

store_dir <- file.path(tempdir(), "rbebelm-framework-sessions")
store <- bebel_session_create(cwd = tempdir(), session_dir = store_dir, name = "fake backend")

loop <- bebel_agent_loop(backend, session = store)
run <- bebel_loop_run(loop, "Hello backend", max_steps = 1)

run$done
#> [1] TRUE
backend$user
#> [1] "Hello backend"
bebel_loop_state(loop)[c("state", "turns", "session_file")]
#> $state
#> [1] "idle"
#> 
#> $turns
#> [1] 1
#> 
#> $session_file
#> [1] "/tmp/Rtmpiqz6mZ/rbebelm-framework-sessions/2026-06-08T23-02-27-587Z_c6be45ee-e358-44e7-ec1d-6ada44bc15ee.jsonl"
```

The loop writes generic message entries to the session store. The
backend keeps its own transcript/cache state; the session file stores
portable framework history for replay, browsing, forking, sharing, and
UI state.

``` r

context <- bebel_session_context(store)
vapply(context$messages, `[[`, character(1), "role")
#> [1] "user"      "assistant"
readLines(bebel_session_file(store), n = 3)
#> [1] "{\"type\":\"session\",\"version\":3,\"id\":\"c6be45ee-e358-44e7-ec1d-6ada44bc15ee\",\"timestamp\":\"2026-06-08T23:02:27.586Z\",\"cwd\":\"/tmp/Rtmpiqz6mZ\"}"                                        
#> [2] "{\"type\":\"session_info\",\"id\":\"3f1285a6\",\"parentId\":null,\"timestamp\":\"2026-06-08T23:02:27.590Z\",\"name\":\"fake backend\"}"                                                             
#> [3] "{\"type\":\"message\",\"id\":\"f4585e9f\",\"parentId\":\"3f1285a6\",\"timestamp\":\"2026-06-08T23:02:27.608Z\",\"message\":{\"role\":\"user\",\"content\":\"Hello backend\",\"source\":\"prompt\"}}"
```

## JSONL session trees

Sessions are inspired by Pi’s JSONL session format. The first line is a
session header; every other entry has an `id`, `parentId`, `timestamp`,
and `type`. Entries form a tree, not only a linear log. Moving the leaf
to an earlier entry and appending creates a new branch without deleting
the old path.

Default persisted sessions live under:

``` r
tools::R_user_dir("Rbebelm", "data")/sessions/<encoded-cwd>/
```

Set `RBEBELM_SESSION_DIR` or pass `session_dir` to override that
location.

``` r

s <- bebel_session_create(cwd = tempdir(), session_dir = store_dir, name = "tree demo")
u1 <- bebel_session_append_message(s, "user", "first question")
a1 <- bebel_session_append_message(
  s,
  "assistant",
  list(list(type = "text", text = "first answer")),
  provider = "fake",
  model = "fake-model",
  stopReason = "stop"
)

bebel_session_checkout(s, u1)
u2 <- bebel_session_append_message(s, "user", "alternate branch")

vapply(bebel_session_branch(s), `[[`, character(1), "type")
#> [1] "session_info" "message"      "message"
length(bebel_session_tree(s)[[1]]$children)
#> [1] 1
```

Session entries include ordinary messages plus metadata and extension
entries:

- `message`
- `custom` for extension state that does **not** enter model context
- `custom_message` for extension-injected context
- `label`
- `session_info`
- `model_change`
- `thinking_level_change`
- `compaction`
- `branch_summary`

``` r

bebel_session_append_custom(s, "my-extension", list(counter = 1L))
#> [1] "1f46a036"
bebel_session_append_custom_message(s, "my-extension", "Hidden context", display = FALSE)
#> [1] "6717828a"
bebel_session_append_label(s, u1, "checkpoint")
#> [1] "c5cc842c"

tail(vapply(bebel_session_entries(s), `[[`, character(1), "type"), 3)
#> [1] "custom"         "custom_message" "label"
```

Forking copies all non-header entries into a new session file with a new
header. Cloning a branch copies only the active path from root to a
selected leaf.

``` r

forked <- bebel_session_fork(bebel_session_file(s), cwd = tempdir(), session_dir = store_dir)
cloned <- bebel_session_clone_branch(s, leaf_id = u2, session_dir = store_dir)

bebel_session_header(forked)$parentSession
#> [1] "/tmp/Rtmpiqz6mZ/rbebelm-framework-sessions/2026-06-08T23-02-27-754Z_512d08e1-470f-b2bb-fa92-169253906552.jsonl"
vapply(bebel_session_entries(cloned), `[[`, character(1), "id")
#> [1] "81f70b06" "b589156b" "040c500c"
```

## Extensions

An extension is a backend-agnostic capability bundle registered into the
loop, not into a particular terminal UI. It should implement the
`BebelAgentExtension` interface:

- `bebel_extension_manifest(extension)`
- `bebel_extension_tools(extension)`
- `bebel_extension_commands(extension)`
- `bebel_extension_hooks(extension)`
- `bebel_extension_skill_providers(extension)`
- `bebel_extension_prompt_template_providers(extension)`

The helper
[`bebel_extension()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_extension.md)
creates a simple extension object implementing that interface.
Extensions register into the loop; they do not own the loop or a TUI.

``` r

state_command <- bebel_loop_command(
  "state",
  function(args, loop, context) bebel_loop_state(loop),
  description = "Return loop state."
)

ext <- bebel_extension(
  "demo-extension",
  commands = list(state = state_command),
  hooks = list(event = function(event, loop, context, ...) {
    context$last_event_type <- event$type
  }),
  metadata = list(ui = "frontends may render this")
)

bebel_extension_manifest(ext)
#> $name
#> [1] "demo-extension"
#> 
#> $tools
#> NULL
#> 
#> $commands
#> $commands$state
#> $commands$state$name
#> [1] "state"
#> 
#> $commands$state$description
#> [1] "Return loop state."
#> 
#> $commands$state$usage
#> [1] "/state"
#> 
#> 
#> 
#> $hooks
#> [1] "event"
#> 
#> $skill_providers
#> NULL
#> 
#> $prompt_template_providers
#> NULL
#> 
#> $keybindings
#> list()
#> 
#> $widgets
#> list()
#> 
#> $metadata
#> $metadata$ui
#> [1] "frontends may render this"
```

When attached to a loop, contributed commands, tools, hooks, skill
providers, and prompt-template providers are available through loop
state and catalogs.

``` r

loop2 <- bebel_agent_loop(backend, extensions = list(ext), session = FALSE)
bebel_loop_command_catalog(loop2)
#>    name        description  usage
#> 1 state Return loop state. /state
bebel_loop_execute_command(loop2, "/state")
#> [1] TRUE
loop2$context$last_event_type
#> [1] "command_end"
```

## Skills and prompt templates

Skill providers and prompt-template providers are separate interfaces so
system prompt loading is not tied to BebeLM. A provider can be
in-memory, file-backed, or package-backed.

``` r

skills <- bebel_skill_provider(list(
  concise = "Prefer concise, direct answers.",
  r_safe = "Avoid side effects unless the user asks for them."
))

prompts <- bebel_prompt_template_provider(list(
  system = "You are {{role}} working in {{place}}."
))

bebel_skill_list(skills)
#>      name description path
#> 1 concise     concise <NA>
#> 2  r_safe      r_safe <NA>
bebel_prompt_template_list(prompts)
#>     name description path
#> 1 system      system <NA>

bebel_system_prompt(
  prompts,
  "system",
  data = list(role = "an R coding agent", place = "Bamako"),
  skill_provider = skills,
  skills = c("concise", "r_safe")
)
#> [1] "You are an R coding agent working in Bamako.\n\n# Loaded skills\n\n## Skill: concise\n\nPrefer concise, direct answers.\n\n## Skill: r_safe\n\nAvoid side effects unless the user asks for them."
```

[`bebel_append_system_prompt()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_append_system_prompt.md)
renders a template, appends selected skills, and then calls
[`bebel_backend_append_system()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_backend_append_system.md).
This keeps system-prompt loading generic; BebeLM-specific tool preamble
details remain inside BebeLM’s backend method.
