# Agents and tools

`Rbebelm` is organized around persistent agents. A `BebelAgent` keeps
token history, generation settings, and decode caches across turns.
Tools are layered on top of agents: the model emits a BebeLM tool-call
block, R parses the call, runs the matching R function, appends the tool
result, and continues generation.

## Agent state

``` r

library(Rbebelm)
model <- bebel_model_load(Sys.getenv("BEBELM_WEIGHTS_FILE"), num_threads = 2)
agent <- bebel_agent(model, greedy = TRUE, max_gen = 48, max_think = 16)

bebel_append_user(agent, "Say exactly: Paris noted.")
turn1 <- bebel_assistant_turn(agent, on_event = NULL)

bebel_append_user(agent, "Say exactly: second turn complete.")
turn2 <- bebel_assistant_turn(agent, on_event = NULL)

bebel_agent_info(agent)[c("history_tokens", "processed_tokens", "kv_tokens")]
#> $history_tokens
#> [1] 82
#>
#> $processed_tokens
#> [1] 80
#>
#> $kv_tokens
#> [1] 80

# Direct methods are available on the agent object.
length(agent$history())
#> [1] 82
substr(agent$transcript(), 1, 80)
#> [1] "<|startoftext|><|im_start|>user\nSay exactly: Paris noted.<|im_end|>\n<|im_start|>"

# Helper functions provide the same operations.
length(bebel_history(agent))
#> [1] 82
substr(bebel_transcript(agent), 1, 80)
#> [1] "<|startoftext|><|im_start|>user\nSay exactly: Paris noted.<|im_end|>\n<|im_start|>"

# Reset the conversation while keeping the loaded weights and generation settings.
agent$clear()[c("history_tokens", "processed_tokens", "kv_tokens")]
#> $history_tokens
#> [1] 0
#>
#> $processed_tokens
#> [1] 0
#>
#> $kv_tokens
#> [1] 0
```

Use
[`bebel_append_system()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_append_system.md)
for an upstream-rendered ChatML system turn. With no tools, the
low-level
[`bebel_append()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_append.md)
form below is equivalent apart from being more explicit about the
tokens. When `tools` are supplied, BebeLM renders its
`List of tools: [...]` system preamble.

``` r

system_agent <- bebel_agent(model)
bebel_append_system(system_agent, "You are concise.")
bebel_transcript(system_agent)
#> [1] "<|startoftext|><|im_start|>system\nYou are concise.<|im_end|>\n"

raw_system_agent <- bebel_agent(model)
bebel_append(raw_system_agent, "<|im_start|>system\nYou are concise.<|im_end|>\n")
identical(bebel_transcript(system_agent), bebel_transcript(raw_system_agent))
#> [1] TRUE

raw_agent <- bebel_agent(model, greedy = TRUE, max_gen = 16, max_think = 0)
bebel_append(raw_agent, "The capital of Mali is")
raw_turn <- bebel_agent_generate(raw_agent, on_event = NULL)
raw_turn[c("stop", "generated_tokens")]
#> $stop
#> [1] "max_new"
#>
#> $generated_tokens
#> [1] 16

ids <- bebel_tokenize(model, " and Italy is", add_bos = FALSE)
bebel_append_tokens(raw_agent, ids)
bebel_history(raw_agent)[1:8]
#> [1] 124894    597   5205    302  46628    355  50593   6261
```

## Tool definitions

A tool is an R function plus metadata. The `context` environment is
private to R and is not appended to the model transcript.

``` r

library(Rbebelm)
ctx <- new.env(parent = emptyenv())
ctx$thread_id <- "thread-001"
ctx$log <- character()

tools <- list(
  lookup_capital = bebel_tool(
    "lookup_capital",
    function(args, context, call) {
      context$log <- c(context$log, paste("tool", call$name, args$country))
      c(Mali = "Bamako", Italy = "Rome")[[args$country]]
    },
    description = "Return a capital city for a country."
  )
)

tools$lookup_capital
#> <bebelTool> lookup_capital
#>   Return a capital city for a country.
```

The default parser delegates BebeLM’s bracketed Pythonic tool-call form
to upstream, including multiple calls. JSON object calls and legacy
`name({...})` compatibility are parsed with imported `yyjsonr`.

``` r

bebel_parse_tool_call('[lookup_capital(country="Italy")]')
#> $name
#> [1] "lookup_capital"
#>
#> $arguments
#> $arguments$country
#> [1] "Italy"
#>
#>
#> $raw
#> [1] "lookup_capital(country=\"Italy\")"
bebel_parse_tool_calls('[lookup_capital(country="Mali"), lookup_capital(country="Italy")]')
#> [[1]]
#> [[1]]$name
#> [1] "lookup_capital"
#>
#> [[1]]$arguments
#> [[1]]$arguments$country
#> [1] "Mali"
#>
#>
#> [[1]]$raw
#> [1] "lookup_capital(country=\"Mali\")"
#>
#>
#> [[2]]
#> [[2]]$name
#> [1] "lookup_capital"
#>
#> [[2]]$arguments
#> [[2]]$arguments$country
#> [1] "Italy"
#>
#>
#> [[2]]$raw
#> [1] "lookup_capital(country=\"Italy\")"
```

## Run a tool loop

[`bebel_agent_run()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_run.md)
dispatches tools only when generation emits a BebeLM `tool_call_end`
event. The prompt below asks directly for the tool-call form so the
example exercises the dispatch path.

``` r

hooks <- list(
  tool_request = function(call, context, ...) {
    context$log <- c(context$log, paste("request", call$name))
  },
  tool_result = function(call, result, context, ...) {
    context$log <- c(context$log, paste("result", call$name, result))
  }
)

tool_prompt <- paste(
  "Return exactly this tool call and no other text:",
  "lookup_capital({\"country\":\"Italy\"})"
)

agent <- bebel_agent(model, greedy = TRUE, max_gen = 64, max_think = 0)
bebel_append_user(agent, tool_prompt)
run <- bebel_agent_run(agent, tools = tools, context = ctx, hooks = hooks, max_steps = 2)

length(run$tool_calls)
#> [1] 1
ctx$log
#> [1] "request lookup_capital"     "tool lookup_capital Italy"
#> [3] "result lookup_capital Rome"
```

If a model uses a different tool-call format, pass a custom
`parse_tool_call` function to
[`bebel_agent_run()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_run.md).
