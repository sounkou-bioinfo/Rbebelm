# Getting started

`Rbebelm` provides `R` bindings to `BebeLM`, a Rust implementation of
local `CPU` inference for [Liquid AI
LFM2.5-8B-A1B](https://www.liquid.ai/blog/lfm2-5-8b-a1b) GGUF weights.
Model weights are not bundled with the package. Set
`BEBELM_WEIGHTS_FILE` to a local GGUF path before running the model
examples.

``` r

library(Rbebelm)
rbebelm_backend_info()
#> <Rbebelm backend dispatch>
#>   mode: dynamic 
#>   requested: auto 
#>   selected: avx2 
#>   loaded: yes 
#>   installed: scalar,avx2,avx512 
#>   supported: scalar,avx2
```

## Load a model

``` r

model <- bebel_model_load(Sys.getenv("BEBELM_WEIGHTS_FILE"), num_threads = 2)
rbebelm_backend_features()[c("backend", "target_arch", "target_os")]
#> $backend
#> [1] "avx2"
#> 
#> $target_arch
#> [1] "x86_64"
#> 
#> $target_os
#> [1] "linux"
```

If `BEBELM_WEIGHTS_FILE` is not set, use the same code with an explicit
file path:

``` r

model <- bebel_model_load("LFM2.5-8B-A1B-Q4_K_M.gguf", num_threads = 2)
```

## Use an agent

The main interface is `BebelAgent`. An agent owns the transcript and
decode caches while sharing the loaded model weights.

``` r

agent <- bebel_agent(model, greedy = TRUE, max_gen = 48, max_think = 16)

bebel_append_user(agent, "What is the capital of Mali? Answer briefly.")
turn1 <- bebel_assistant_turn(agent, on_event = NULL)

bebel_append_user(agent, "What about Italy?")
turn2 <- bebel_assistant_turn(agent, on_event = NULL)

turn1$text
#> [1] "<think>\nThe user asks: \"What is the capital of Mali? Answer briefly.\"</think>\nThe capital of Mali is Bamako."
turn2$text
#> [1] "<think>\nThe user asks: \"What about Italy? Answer briefly.\" Likely they</think>\nThe capital of Italy is Rome."
bebel_agent_info(agent)[c("history_tokens", "processed_tokens", "kv_tokens")]
#> $history_tokens
#> [1] 88
#> 
#> $processed_tokens
#> [1] 86
#> 
#> $kv_tokens
#> [1] 86
```

Use `bebel_clear(agent)` to reset transcript and caches without
reloading the model.

## Convenience calls

For simple calls,
[`bebel_chat()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_chat.md)
creates a single ChatML user/assistant turn. For raw prompt completion,
use
[`bebel_generate()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_generate.md).

``` r

chat <- bebel_chat(
  model,
  "In one concise sentence, what does runtime backend dispatch do?",
  greedy = TRUE,
  max_gen = 48,
  max_think = 16,
  on_event = NULL
)
chat$text
#> [1] "<think>\nThe user asks: \"In one concise sentence, what does runtime backend dispatch</think>\nRuntime backend dispatch assigns incoming requests to the appropriate service or function based on dynamic criteria at execution time. That's one sentence. But they want \""
```

## Token helpers

``` r

ids <- bebel_tokenize(model, "The capital of Italy is", add_bos = TRUE)
ids
#> [1] 124894    597   5205    302  10125    355
bebel_detokenize(model, ids)
#> [1] "<|startoftext|>The capital of Italy is"
bebel_token_ids()[c("TOKEN_THINK", "TOKEN_TOOL_CALL_START", "TOKEN_TOOL_CALL_END")]
#>           TOKEN_THINK TOKEN_TOOL_CALL_START   TOKEN_TOOL_CALL_END 
#>                124901                124905                124906
```
