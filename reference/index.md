# Package index

## Model loading and tokenizer

- [`bebel_model_load()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_model_load.md)
  : Load a BebeLM GGUF model
- [`bebel_tokenize()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tokenize.md)
  : Tokenize text with a BebeLM model tokenizer
- [`bebel_detokenize()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_detokenize.md)
  : Decode BebeLM token ids
- [`bebel_token_ids()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_token_ids.md)
  : Return BebeLM tokenizer special token ids.
- [`BebelModel`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelModel.md)
  : Loaded BebeLM GGUF model.
- [`BebelModelRef()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelModelRef.md)
  : BebeLM model reference
- [`BebelModelLoadOptions()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelModelLoadOptions.md)
  : Model loading options
- [`BebelScalarText()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelScalarText.md)
  : Scalar non-empty text

## Embeddings

- [`bebel_embed()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_embed.md)
  : Embed text with pooled BebeLM hidden states
- [`BebelEmbeddingOptions()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelEmbeddingOptions.md)
  : Embedding options

## Generation and agents

- [`bebel_generate()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_generate.md)
  : Generate a raw continuation from a prompt
- [`bebel_chat()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_chat.md)
  : Generate a single ChatML assistant reply
- [`bebel_agent()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent.md)
  : Create a persistent BebeLM agent
- [`bebel_agent_configure()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_configure.md)
  : Configure a BebeLM agent
- [`bebel_agent_info()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_info.md)
  : Inspect a BebeLM agent
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
- [`bebel_clear()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_clear.md)
  : Clear a BebeLM agent transcript and caches
- [`bebel_history()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_history.md)
  : Return a BebeLM agent token transcript
- [`bebel_transcript()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_transcript.md)
  : Decode a BebeLM agent transcript
- [`BebelAgent`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelAgent.md)
  : Persistent BebeLM conversation agent with transcript and decode
  caches.
- [`BebelAgentRef()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelAgentRef.md)
  : BebeLM agent reference
- [`BebelGenerationOptions()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelGenerationOptions.md)
  : Generation options
- [`BebelAgentOptions()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelAgentOptions.md)
  : Agent construction options
- [`BebelAgentConfigureOptions()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelAgentConfigureOptions.md)
  : Agent configuration update

## Async jobs

- [`bebel_generate_async()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_generate_async.md)
  : Start a background raw generation job
- [`bebel_chat_async()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_chat_async.md)
  : Start a background ChatML assistant reply job
- [`bebel_agent_generate_async()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_generate_async.md)
  : Start a background raw agent generation job
- [`bebel_assistant_turn_async()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_assistant_turn_async.md)
  : Start a background assistant-turn job
- [`bebel_assistant_turn_tool_stop_async()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_assistant_turn_tool_stop_async.md)
  : Start a background assistant-turn job that stops on tool-call close
- [`bebel_async_poll()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_async_poll.md)
  : Poll a BebeLM async job
- [`bebel_async_events()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_async_events.md)
  : Drain queued BebeLM async job events
- [`bebel_async_wait()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_async_wait.md)
  : Wait for a BebeLM async job
- [`bebel_async_collect()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_async_collect.md)
  : Collect a BebeLM async job result
- [`bebel_async_cancel()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_async_cancel.md)
  : Cancel a BebeLM async job
- [`BebelAsyncJob`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelAsyncJob.md)
  : Background BebeLM generation job.
- [`BebelAsyncJobRef()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelAsyncJobRef.md)
  : BebeLM async job reference
- [`BebelAsyncEventDrainOptions()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelAsyncEventDrainOptions.md)
  : Async event drain options
- [`BebelAsyncWaitOptions()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelAsyncWaitOptions.md)
  : Async wait options

## Benchmarks

- [`bebel_benchmark_generation()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_benchmark_generation.md)
  : Benchmark async BebeLM generation throughput
- [`BebelGenerationBenchmarkOptions()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelGenerationBenchmarkOptions.md)
  : Generation benchmark options

## Tools and events

- [`bebel_tool()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool.md)
  : Define a BebeLM R tool
- [`bebel_tool_schema_json()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_tool_schema_json.md)
  : Render a BebeLM tool schema
- [`bebel_parse_tool_call()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_parse_tool_call.md)
  : Parse a single BebeLM tool call block
- [`bebel_parse_tool_calls()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_parse_tool_calls.md)
  : Parse BebeLM tool calls
- [`bebel_agent_run()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_run.md)
  : Run a BebeLM agent with R tool dispatch
- [`bebel_event_types()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_event_types.md)
  : Return BebeLM stream event types.
- [`bebel_event_handler()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_event_handler.md)
  : Build a BebeLM generation event handler
- [`BebelToolSpec()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelToolSpec.md)
  : R tool exposed to BebeLM
- [`BebelToolRef()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelToolRef.md)
  : BebeLM tool reference
- [`BebelAgentRunOptions()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/BebelAgentRunOptions.md)
  : Agent run options

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
