# Events and adapters

Generation in `Rbebelm` is event-based. The Rust decode loop emits a
finite event protocol reported by
[`bebel_event_types()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_event_types.md).

``` r

library(Rbebelm)
bebel_event_types()
#>  [1] "start"           "thinking_start"  "thinking_delta"  "thinking_end"   
#>  [5] "text_start"      "text_delta"      "text_end"        "tool_list_start"
#>  [9] "tool_list_delta" "tool_list_end"   "tool_call_start" "tool_call_delta"
#> [13] "tool_call_end"   "done"
```

Events describe stream lifecycle, thinking blocks, answer text blocks,
tool-list blocks, tool-call blocks, and completion. Console output is
just one event handler:
[`bebel_console_event()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_console_event.md).

## Collect text deltas

Use `on_event = NULL` for silent generation, or provide a callback to
consume selected events.

``` r

model <- bebel_model_load(Sys.getenv("BEBELM_WEIGHTS_FILE"), num_threads = 2)
text <- character()
thinking <- character()

turn <- bebel_generate(
  model,
  "A text delta callback can",
  greedy = TRUE,
  max_gen = 12,
  max_think = 16,
  on_event = bebel_event_handler(
    text_delta = function(event) text <<- c(text, event$delta),
    thinking_delta = function(event) thinking <<- c(thinking, event$delta)
  )
)

paste0(text, collapse = "")
#> [1] " be used to update a text field in a UI component."
turn[c("stop", "generated_tokens")]
#> $stop
#> [1] "max_new"
#> 
#> $generated_tokens
#> [1] 12
```

## Handler lists

A named list can also be supplied directly. Unknown handler names are
rejected so stale event code fails early.

``` r

counts <- c(text_delta = 0L, thinking_delta = 0L, done = 0L)

invisible(bebel_generate(
  model,
  "An event handler list can",
  greedy = TRUE,
  max_gen = 4,
  max_think = 16,
  on_event = list(
    text_delta = function(event) counts["text_delta"] <<- counts[["text_delta"]] + 1L,
    thinking_delta = function(event) counts["thinking_delta"] <<- counts[["thinking_delta"]] + 1L,
    done = function(event) counts["done"] <<- counts[["done"]] + 1L
  )
))

counts
#>     text_delta thinking_delta           done 
#>              4              0              1
```

## SSE example

An SSE endpoint can serialize each event as it arrives. The sketch below
shows the adapter shape; the exact response object depends on the web
framework.

``` r

sse_handler <- function(response) {
  bebel_event_handler(
    default = function(event) {
      payload <- jsonlite::toJSON(event, auto_unbox = TRUE, null = "null")
      response$write(paste0("event: ", event$type, "\n"))
      response$write(paste0("data: ", payload, "\n\n"))
      response$flush()
    }
  )
}

bebel_agent_generate(agent, on_event = sse_handler(response))
```

Tool adapters use the same event stream.
[`bebel_agent_run()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_agent_run.md)
listens for `tool_call_end` events, parses their accumulated content,
invokes R tools, and appends tool results to the transcript.
