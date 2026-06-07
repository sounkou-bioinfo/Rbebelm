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
  : Append a ChatML system turn to a BebeLM agent transcript
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
- [`bebel_agent_run()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_run.md)
  : Run a BebeLM agent with R tool dispatch
- [`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md)
  : Define a BebeLM R tool
- [`bebel_parse_tool_call()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_parse_tool_call.md)
  : Parse a BebeLM tool call block
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

## R-native agent layer

- [`bebel_r_agent()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent.md)
  : Create an R-native Rbebelm agent session
- [`bebel_r_agent_turn()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent_turn.md)
  : Run one user turn through an Rbebelm R agent
- [`bebel_r_agent_console()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_r_agent_console.md)
  : Start an interactive Rbebelm console agent
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
