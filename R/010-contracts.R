#' Rbebelm agent framework contracts
#'
#' These S7/s7contract interfaces keep the loop, extension, skill, and prompt
#' infrastructure independent from the concrete LLM backend. BebeLM implements
#' `AgentBackend`; other local or remote providers can implement the same
#' generics later.
#'
#' @name rbebelm_contracts
NULL

#' Append a user message to an agent backend
#' @param agent An object implementing [AgentBackend].
#' @param message User message text.
#' @export
agent_append_user <- S7::new_generic("agent_append_user", "agent", function(agent, message) S7::S7_dispatch())

#' Append a system message to an agent backend
#' @param agent An object implementing [AgentBackend].
#' @param message System message text.
#' @param tools Optional backend-native tool declarations.
#' @export
agent_append_system <- S7::new_generic("agent_append_system", "agent", function(agent, message, tools = NULL) S7::S7_dispatch())

#' Append a tool result to an agent backend
#' @param agent An object implementing [AgentBackend].
#' @param content Tool result content.
#' @export
agent_append_tool_result <- S7::new_generic("agent_append_tool_result", "agent", function(agent, content) S7::S7_dispatch())

#' Run one assistant turn on an agent backend
#' @param agent An object implementing [AgentBackend].
#' @param on_event Optional stream event callback.
#' @param check_interrupt Check for Ctrl-C during generation.
#' @param stop_on_tool_call Stop after a tool-call delimiter when supported.
#' @export
agent_assistant_turn <- S7::new_generic(
  "agent_assistant_turn",
  "agent",
  function(agent, on_event = NULL, check_interrupt = TRUE, stop_on_tool_call = FALSE) S7::S7_dispatch()
)

#' Return agent backend information
#' @param agent An object implementing [AgentBackend].
#' @export
agent_info <- S7::new_generic("agent_info", "agent", function(agent) S7::S7_dispatch())

#' Return agent backend transcript text
#' @param agent An object implementing [AgentBackend].
#' @export
agent_transcript <- S7::new_generic("agent_transcript", "agent", function(agent) S7::S7_dispatch())

#' Clear an agent backend
#' @param agent An object implementing [AgentBackend].
#' @export
agent_clear <- S7::new_generic("agent_clear", "agent", function(agent) S7::S7_dispatch())

#' Return an extension manifest
#' @param extension An object implementing [AgentExtension].
#' @export
extension_manifest <- S7::new_generic("extension_manifest", "extension", function(extension) S7::S7_dispatch())

#' Return tools contributed by an extension
#' @param extension An object implementing [AgentExtension].
#' @export
extension_tools <- S7::new_generic("extension_tools", "extension", function(extension) S7::S7_dispatch())

#' Return commands contributed by an extension
#' @param extension An object implementing [AgentExtension].
#' @export
extension_commands <- S7::new_generic("extension_commands", "extension", function(extension) S7::S7_dispatch())

#' Return hooks contributed by an extension
#' @param extension An object implementing [AgentExtension].
#' @export
extension_hooks <- S7::new_generic("extension_hooks", "extension", function(extension) S7::S7_dispatch())

#' Return skill providers contributed by an extension
#' @param extension An object implementing [AgentExtension].
#' @export
extension_skill_providers <- S7::new_generic("extension_skill_providers", "extension", function(extension) S7::S7_dispatch())

#' Return prompt-template providers contributed by an extension
#' @param extension An object implementing [AgentExtension].
#' @export
extension_prompt_template_providers <- S7::new_generic("extension_prompt_template_providers", "extension", function(extension) S7::S7_dispatch())

#' List available skills
#' @param provider A skill provider.
#' @export
skill_list <- S7::new_generic("skill_list", "provider", function(provider) S7::S7_dispatch())

#' Load a skill by name
#' @param provider A skill provider.
#' @param name Skill name.
#' @export
skill_load <- S7::new_generic("skill_load", "provider", function(provider, name) S7::S7_dispatch())

#' List prompt templates
#' @param provider A prompt-template provider.
#' @export
prompt_template_list <- S7::new_generic("prompt_template_list", "provider", function(provider) S7::S7_dispatch())

#' Render a prompt template
#' @param provider A prompt-template provider.
#' @param name Template name.
#' @param data Template data.
#' @export
prompt_template_render <- S7::new_generic("prompt_template_render", "provider", function(provider, name, data = list()) S7::S7_dispatch())

#' Agent backend interface
#'
#' Backends implement the minimal transcript/generation protocol consumed by
#' [bebel_agent_loop()].
#'
#' @export
AgentBackend <- s7contract::new_interface(
  "AgentBackend",
  generics = list(
    agent_append_user = agent_append_user,
    agent_append_system = agent_append_system,
    agent_append_tool_result = agent_append_tool_result,
    agent_assistant_turn = agent_assistant_turn,
    agent_info = agent_info,
    agent_transcript = agent_transcript,
    agent_clear = agent_clear
  )
)

#' Agent extension interface
#'
#' Extensions expose a manifest plus contributed tools, commands, and hooks.
#'
#' @export
AgentExtension <- s7contract::new_interface(
  "AgentExtension",
  generics = list(
    extension_manifest = extension_manifest,
    extension_tools = extension_tools,
    extension_commands = extension_commands,
    extension_hooks = extension_hooks,
    extension_skill_providers = extension_skill_providers,
    extension_prompt_template_providers = extension_prompt_template_providers
  )
)

#' Skill provider interface
#'
#' Skill providers list and load reusable instructions or workflow snippets.
#'
#' @export
SkillProvider <- s7contract::new_interface(
  "SkillProvider",
  generics = list(skill_list = skill_list, skill_load = skill_load)
)

#' Prompt-template provider interface
#'
#' Prompt-template providers list and render named templates.
#'
#' @export
PromptTemplateProvider <- s7contract::new_interface(
  "PromptTemplateProvider",
  generics = list(prompt_template_list = prompt_template_list, prompt_template_render = prompt_template_render)
)

bebel_assert_implements <- function(x, interface, arg = deparse(substitute(x))) {
  if (s7contract::implements(x, interface)) return(invisible(x))

  for (cls in class(x)) {
    adapter <- tryCatch(S7::new_S3_class(cls), error = function(e) NULL)
    if (!is.null(adapter) && s7contract::implements(adapter, interface)) return(invisible(x))
  }

  s7contract::assert_implements(x, interface, arg = arg)
}

BebelAgentS3 <- S7::new_S3_class("BebelAgent")
BebelExtensionS3 <- S7::new_S3_class("bebelExtension")

S7::method(agent_append_user, BebelAgentS3) <- function(agent, message) {
  bebel_append_user(agent, message)
  agent
}

S7::method(agent_append_system, BebelAgentS3) <- function(agent, message, tools = NULL) {
  bebel_append_system(agent, message, tools = tools)
  agent
}

S7::method(agent_append_tool_result, BebelAgentS3) <- function(agent, content) {
  bebel_append_tool_result(agent, content)
  agent
}

S7::method(agent_assistant_turn, BebelAgentS3) <- function(agent, on_event = NULL, check_interrupt = TRUE, stop_on_tool_call = FALSE) {
  if (isTRUE(stop_on_tool_call)) {
    bebel_assistant_turn_tool_stop(agent, on_event = on_event, check_interrupt = check_interrupt)
  } else {
    bebel_assistant_turn(agent, on_event = on_event, check_interrupt = check_interrupt)
  }
}

S7::method(agent_info, BebelAgentS3) <- function(agent) {
  bebel_agent_info(agent)
}

S7::method(agent_transcript, BebelAgentS3) <- function(agent) {
  bebel_transcript(agent)
}

S7::method(agent_clear, BebelAgentS3) <- function(agent) {
  bebel_clear(agent)
  agent
}

S7::method(extension_tools, BebelExtensionS3) <- function(extension) extension$tools
S7::method(extension_commands, BebelExtensionS3) <- function(extension) extension$commands
S7::method(extension_hooks, BebelExtensionS3) <- function(extension) extension$hooks
S7::method(extension_skill_providers, BebelExtensionS3) <- function(extension) extension$skill_providers %||% list()
S7::method(extension_prompt_template_providers, BebelExtensionS3) <- function(extension) extension$prompt_template_providers %||% list()
S7::method(extension_manifest, BebelExtensionS3) <- function(extension) {
  list(
    name = extension$name,
    tools = names(extension_tools(extension)),
    commands = lapply(extension_commands(extension), function(command) {
      list(name = command$name, description = command$description, usage = command$usage)
    }),
    hooks = names(extension_hooks(extension)),
    skill_providers = names(extension_skill_providers(extension)),
    prompt_template_providers = names(extension_prompt_template_providers(extension)),
    keybindings = extension$keybindings,
    widgets = extension$widgets,
    metadata = extension$metadata
  )
}
