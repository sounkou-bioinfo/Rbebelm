# Agents and tools

``` r

library(Rbebelm)
weights_file <- Sys.getenv("BEBELM_WEIGHTS_FILE", "/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf")
stopifnot(file.exists(weights_file))
model <- bebel_model_load(weights_file, num_threads = 2)
```

`BebelAgent` is the stateful unit: it owns transcript tokens and caches,
while the loaded weights remain shared.

``` r

agent <- bebel_agent(model, greedy = TRUE, max_gen = 16, max_think = 0)
bebel_append_system(agent, "You are concise.")
bebel_append_user(agent, "Say exactly: first turn.")
first <- bebel_assistant_turn(agent, on_event = NULL)

bebel_append_user(agent, "Say exactly: second turn.")
second <- bebel_assistant_turn(agent, on_event = NULL)

first
```

    ## <BebeLM assistant turn>
    ##   stop: eos
    ##   tokens: 9 generated; 24 prompt
    ##   prefill: 11.6 tok/s
    ##   decode: 7.87 tok/s
    ##   text:
    ## <STEP_2> first turn.

``` r

second
```

    ## <BebeLM assistant turn>
    ##   stop: max_new
    ##   tokens: 16 generated; 16 prompt
    ##   prefill: 10.8 tok/s
    ##   decode: 8.34 tok/s
    ##   text:
    ## <STEP_3> second turn.</think>
    ## <STEP_2

``` r

bebel_agent_info(agent)[c("history_tokens", "processed_tokens", "kv_tokens")]
```

    ## $history_tokens
    ## [1] 67
    ## 
    ## $processed_tokens
    ## [1] 64
    ## 
    ## $kv_tokens
    ## [1] 64

``` r

substr(bebel_transcript(agent), 1, 160)
```

    ## [1] "<|startoftext|><|im_start|>system\nYou are concise.<|im_end|>\n<|im_start|>user\nSay exactly: first turn.<|im_end|>\n<|im_start|>assistant\n<STEP_2> first turn.<|im_"

Tools are S7 objects with a name, an R function, optional description,
and optional schema. Tool-call parsing is delegated to upstream BebeLM
for the bracketed call format.

``` r

lookup_capital <- bebel_tool(
  "lookup_capital",
  function(args, context, call) {
    context$calls <- c(context$calls, paste(call$name, args$country))
    c(Mali = "Bamako", Italy = "Rome")[[args$country]]
  },
  description = "Return a capital city.",
  schema = list(
    properties = list(country = list(type = "string")),
    required = list("country")
  )
)

lookup_capital
```

    ## <BebelToolSpec> lookup_capital
    ##   Return a capital city.

``` r

bebel_tool_schema_json(lookup_capital)
```

    ## [1] "{\"name\":\"lookup_capital\",\"description\":\"Return a capital city.\",\"parameters\":{\"properties\":{\"country\":{\"type\":\"string\"}},\"required\":[\"country\"],\"type\":\"object\"}}"

``` r

ctx <- new.env(parent = emptyenv())
ctx$calls <- character()
call <- bebel_parse_tool_call('[lookup_capital(country="Italy")]')
Rbebelm:::invoke_bebel_tool(lookup_capital, call, ctx)
```

    ## [1] "Rome"

``` r

ctx$calls
```

    ## [1] "lookup_capital Italy"

[`bebel_agent_run()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_run.md)
wires event collection, parsing, R tool invocation, and tool result
appending. It runs tools only when the generated turn contains a
tool-call block.

``` r

hooks <- list(
  tool_request = function(call, context, ...) {
    context$calls <- c(context$calls, paste("request", call$name))
  },
  tool_result = function(call, result, context, ...) {
    context$calls <- c(context$calls, paste("result", result))
  }
)

runner <- bebel_agent(model, greedy = TRUE, max_gen = 48, max_think = 0)
bebel_append_user(runner, "Answer with exactly this tool call: [lookup_capital(country=\"Mali\")]")
run <- bebel_agent_run(
  runner,
  tools = list(lookup_capital),
  context = ctx,
  hooks = hooks,
  max_steps = 2,
  on_event = NULL
)

length(run$turns)
```

    ## [1] 2

``` r

length(run$tool_calls)
```

    ## [1] 1

``` r

ctx$calls
```

    ## [1] "lookup_capital Italy"   "request lookup_capital" "lookup_capital Mali"   
    ## [4] "result Bamako"
