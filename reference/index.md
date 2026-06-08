# Package index

## Model loading and generation

- [`bebel_model_load()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_model_load.md)
  : Load a BebeLM GGUF model
- [`bebel_generate()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_generate.md)
  : Generate a raw continuation from a prompt
- [`bebel_chat()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_chat.md)
  : Generate a single ChatML assistant reply
- [`bebel_agent()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent.md)
  : Create a persistent BebeLM agent
- [`bebel_append()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_append.md)
  : Append raw text to a BebeLM agent transcript
- [`bebel_append_system()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_append_system.md)
  : Append an upstream BebeLM system turn to an agent transcript
- [`bebel_append_user()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_append_user.md)
  : Append a ChatML user turn to a BebeLM agent transcript
- [`bebel_append_tokens()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_append_tokens.md)
  : Append token ids to a BebeLM agent transcript
- [`bebel_append_tool_result()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_append_tool_result.md)
  : Append a ChatML tool result turn to a BebeLM agent transcript
- [`bebel_agent_generate()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_generate.md)
  : Generate a raw continuation from a BebeLM agent transcript
- [`bebel_assistant_turn()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_assistant_turn.md)
  : Generate and close an assistant ChatML turn from a BebeLM agent
- [`bebel_assistant_turn_tool_stop()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_assistant_turn_tool_stop.md)
  : Open an assistant turn and stop when a tool call closes
- [`bebel_agent_run()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_run.md)
  : Run a BebeLM agent with R tool dispatch
- [`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md)
  : Define a BebeLM R tool
- [`bebel_tool_schema_json()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool_schema_json.md)
  : Render a BebeLM tool schema
- [`bebel_parse_tool_call()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_parse_tool_call.md)
  : Parse a single BebeLM tool call block
- [`bebel_parse_tool_calls()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_parse_tool_calls.md)
  : Parse BebeLM tool calls
- [`bebel_agent_configure()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_configure.md)
  : Configure a BebeLM agent
- [`bebel_agent_info()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_info.md)
  : Inspect a BebeLM agent
- [`bebel_clear()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_clear.md)
  : Clear a BebeLM agent transcript and caches
- [`bebel_history()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_history.md)
  : Return a BebeLM agent token transcript
- [`bebel_transcript()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_transcript.md)
  : Decode a BebeLM agent transcript
- [`bebel_event_types()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_event_types.md)
  : Return BebeLM stream event types.
- [`bebel_event_handler()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_event_handler.md)
  : Build a BebeLM generation event handler
- [`bebel_console_event()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_console_event.md)
  : Console event handler for generated text and thinking
- [`bebel_tokenize()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tokenize.md)
  : Tokenize text with a BebeLM model tokenizer
- [`bebel_detokenize()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_detokenize.md)
  : Decode BebeLM token ids
- [`bebel_token_ids()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_token_ids.md)
  : Return BebeLM tokenizer special token ids.
- [`bebel_live_console()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_live_console.md)
  : Live terminal console for BebeLM chats
- [`BebelModel`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelModel.md)
  : Loaded BebeLM GGUF model.
- [`BebelAgent`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelAgent.md)
  : Persistent BebeLM conversation agent with transcript and decode
  caches.

## Generic agent and frontend framework

- [`rbebelm_contracts`](https://sounkou-bioinfo.github.io/Rbebelm/reference/rbebelm_contracts.md)
  : Rbebelm agent framework contracts
- [`BebelAgentBackend`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelAgentBackend.md)
  : BebeLM agent backend interface
- [`BebelAgentExtension`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelAgentExtension.md)
  : BebeLM agent extension interface
- [`BebelSkillProvider`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelSkillProvider.md)
  : BebeLM skill provider interface
- [`BebelPromptTemplateProvider`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelPromptTemplateProvider.md)
  : BebeLM prompt-template provider interface
- [`bebel_backend_append_user()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_backend_append_user.md)
  : Append a user message to an agent backend
- [`bebel_backend_append_system()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_backend_append_system.md)
  : Append a system message to an agent backend
- [`bebel_backend_append_tool_result()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_backend_append_tool_result.md)
  : Append a tool result to an agent backend
- [`bebel_backend_assistant_turn()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_backend_assistant_turn.md)
  : Run one assistant turn on an agent backend
- [`bebel_backend_info()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_backend_info.md)
  : Return agent backend information
- [`bebel_backend_transcript()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_backend_transcript.md)
  : Return agent backend transcript text
- [`bebel_backend_clear()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_backend_clear.md)
  : Clear an agent backend
- [`bebel_agent_loop()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_loop.md)
  : Create a stateful BebeLM agent loop
- [`bebel_r_agent_loop()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent_loop.md)
  : Create an agent loop from an R-native agent session
- [`bebel_loop_policy()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_policy.md)
  : Create an Agent-loop policy
- [`bebel_loop_run()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_run.md)
  : Run an agent loop
- [`bebel_loop_step()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_step.md)
  : Run one agent-loop assistant/tool step
- [`bebel_loop_prompt()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_prompt.md)
  : Prompt an agent loop
- [`bebel_loop_steer()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_steer.md)
  : Queue a steering message
- [`bebel_loop_follow_up()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_follow_up.md)
  : Queue a follow-up message
- [`bebel_loop_state()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_state.md)
  : Inspect agent-loop state
- [`bebel_loop_events()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_events.md)
  : Return agent-loop events
- [`bebel_loop_extensions()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_extensions.md)
  : Return a loop's extension manifests
- [`bebel_loop_command()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_command.md)
  : Define an agent-loop command
- [`bebel_loop_execute_command()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_execute_command.md)
  : Execute a loop command
- [`bebel_loop_cancel()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_cancel.md)
  : Cancel an agent loop
- [`bebel_loop_clear_queue()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_clear_queue.md)
  : Clear queued steering and follow-up messages
- [`bebel_loop_command_catalog()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_loop_command_catalog.md)
  : Return a loop's command catalog
- [`bebel_extension()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_extension.md)
  : Define an agent-loop extension
- [`bebel_extension_manifest()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_extension_manifest.md)
  : Return an extension manifest
- [`bebel_extension_tools()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_extension_tools.md)
  : Return tools contributed by an extension
- [`bebel_extension_commands()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_extension_commands.md)
  : Return commands contributed by an extension
- [`bebel_extension_hooks()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_extension_hooks.md)
  : Return hooks contributed by an extension
- [`bebel_extension_skill_providers()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_extension_skill_providers.md)
  : Return skill providers contributed by an extension
- [`bebel_extension_prompt_template_providers()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_extension_prompt_template_providers.md)
  : Return prompt-template providers contributed by an extension
- [`bebel_skill_provider()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_skill_provider.md)
  : Create a skill provider
- [`bebel_skill()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_skill.md)
  : Define a framework skill
- [`bebel_skill_list()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_skill_list.md)
  : List available skills
- [`bebel_skill_load()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_skill_load.md)
  : Load a skill by name
- [`bebel_prompt_template_provider()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_prompt_template_provider.md)
  : Create a prompt-template provider
- [`bebel_prompt_template()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_prompt_template.md)
  : Define a prompt template
- [`bebel_prompt_template_list()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_prompt_template_list.md)
  : List prompt templates
- [`bebel_prompt_template_render()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_prompt_template_render.md)
  : Render a prompt template
- [`bebel_system_prompt()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_system_prompt.md)
  : Compose a system prompt from a prompt template and optional skills
- [`bebel_append_system_prompt()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_append_system_prompt.md)
  : Render and append a system prompt to an agent backend

## Session trees and context

- [`bebel_session_create()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_create.md)
  : Create an agent session JSONL store
- [`bebel_session_open()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_open.md)
  : Open an agent session JSONL file
- [`bebel_session_dir()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_dir.md)
  : Agent session storage directory
- [`bebel_session_header()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_header.md)
  [`bebel_session_entries()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_header.md)
  [`bebel_session_leaf_id()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_header.md)
  [`bebel_session_file()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_header.md)
  [`bebel_session_get_entry()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_header.md)
  : Inspect agent session metadata
- [`bebel_session_list()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_list.md)
  : List agent session files
- [`bebel_session_append_message()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_append_message.md)
  : Append a message entry to an agent session
- [`bebel_session_append_session_info()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_append_session_info.md)
  [`bebel_session_append_custom()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_append_session_info.md)
  [`bebel_session_append_custom_message()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_append_session_info.md)
  : Append session metadata and extension entries
- [`bebel_session_append_model_change()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_append_model_change.md)
  [`bebel_session_append_thinking_level_change()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_append_model_change.md)
  [`bebel_session_append_compaction()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_append_model_change.md)
  [`bebel_session_append_branch_summary()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_append_model_change.md)
  : Append model/thinking/compaction/branch metadata
- [`bebel_session_append_label()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_append_label.md)
  : Append or clear a label on a session entry
- [`bebel_session_branch()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_branch.md)
  : Return the branch from root to a session entry
- [`bebel_session_checkout()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_checkout.md)
  : Move the current session leaf
- [`bebel_session_fork()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_fork.md)
  [`bebel_session_clone_branch()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_fork.md)
  : Fork an agent session file into a new session file
- [`bebel_session_context()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_context.md)
  : Build model context from the active session branch
- [`bebel_session_tree()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_session_tree.md)
  : Return an agent session tree

## Native fuzzy file search

- [`bebel_file_finder()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_file_finder.md)
  [`bebel_file_search()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_file_finder.md)
  : Create a native fuzzy file finder
- [`BebelFileFinder`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelFileFinder.md)
  : Persistent native FFF fuzzy file finder.

## R-native agent layer

- [`bebel_r_agent()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent.md)
  : Create an R-native Rbebelm agent session
- [`bebel_r_agent_turn()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent_turn.md)
  : Run one user turn through an Rbebelm R agent
- [`bebel_r_agent_console()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent_console.md)
  : Start an interactive Rbebelm console agent
- [`bebel_r_agent_start()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent_start.md)
  : Launch an R-native Rbebelm console from weights
- [`bebel_r_agent_rpc_server()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent_rpc_server.md)
  : Serve an Rbebelm R agent over JSON-RPC
- [`bebel_r_agent_clear()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent_clear.md)
  : Clear an Rbebelm R agent session
- [`bebel_default_r_tools()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_default_r_tools.md)
  : Built-in R session tools for the Rbebelm agent layer
- [`bebel_agent_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_tool.md)
  : Create an Rbebelm agent tool specification
- [`bebel_agent_tool_catalog()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_tool_catalog.md)
  : Describe an Rbebelm agent tool catalog

## Backend dispatch and diagnostics

- [`rbebelm_set_backend()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/rbebelm_set_backend.md)
  : Select the Rbebelm native backend
- [`rbebelm_backend_info()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/rbebelm_backend_info.md)
  : Inspect Rbebelm backend dispatch state
- [`rbebelm_backend_features()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/rbebelm_backend_features.md)
  : Return feature information reported by the loaded Rust backend.
- [`rbebelm_cpuid_info()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/rbebelm_cpuid_info.md)
  : Inspect CPU SIMD support used by backend dispatch

## S3 methods

- [`print(`*`<bebelGeneration>`*`)`](https://sounkou-bioinfo.github.io/Rbebelm/reference/print.bebelGeneration.md)
  : Print a BebeLM generation result
