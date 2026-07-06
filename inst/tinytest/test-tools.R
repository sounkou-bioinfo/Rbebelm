library(Rbebelm)

call <- bebel_parse_tool_call("[echo(x=1)]")
expect_equal(call$name, "echo")
expect_equal(call$arguments$x, 1)

call2 <- bebel_parse_tool_call('[lookup_capital(country="Italy")]')
expect_equal(call2$name, "lookup_capital")
expect_equal(call2$arguments$country, "Italy")

json_call <- bebel_parse_tool_call('{"name":"lookup_capital","arguments":{"country":"Mali"}}')
expect_equal(json_call$name, "lookup_capital")
expect_equal(json_call$arguments$country, "Mali")

legacy_json_call <- bebel_parse_tool_call('lookup_capital({"country":"Mali"})')
expect_equal(legacy_json_call$name, "lookup_capital")
expect_equal(legacy_json_call$arguments$country, "Mali")

multi <- bebel_parse_tool_calls("[lookup_capital(country='Italy'), add(a=21, b=21)]")
expect_equal(length(multi), 2L)
expect_equal(multi[[1]]$name, "lookup_capital")
expect_equal(multi[[2]]$arguments$a, 21)
expect_equal(multi[[2]]$arguments$b, 21)

schema_json <- Rbebelm:::bebel_tool_schema_json(bebel_tool(
  "lookup_capital",
  function(country) country,
  description = "Look up a capital.",
  schema = list(
    type = "object",
    properties = list(country = list(type = "string", description = "Country name.")),
    required = list("country")
  )
))
expect_true(grepl('"name":"lookup_capital"', schema_json, fixed = TRUE))
expect_true(grepl('"required":["country"]', schema_json, fixed = TRUE))

system_turn <- Rbebelm:::rbebelm_render_system_turn(
  "You are concise.",
  "lookup_capital",
  schema_json
)
expect_true(startsWith(system_turn, "<|im_start|>system\nList of tools: ["))
expect_true(grepl("You are concise.<|im_end|>", system_turn, fixed = TRUE))

ctx <- new.env(parent = emptyenv())
ctx$log <- character()
tool <- bebel_tool("echo", function(args, context, call) {
  context$log <- c(context$log, call$name)
  args
})
expect_true(S7::S7_inherits(tool, BebelToolSpec))
out <- Rbebelm:::invoke_bebel_tool(tool, list(name = "echo", arguments = list(x = 1)), ctx)
expect_equal(out$x, 1)
expect_equal(ctx$log, "echo")

seen <- character()
Rbebelm:::call_bebel_hook(list(tool_request = function(call, ...) seen <<- call$name), "tool_request", call = list(name = "echo"))
expect_equal(seen, "echo")

expect_error(BebelScalarText(value = ""))
expect_error(BebelGenerationOptions(
  greedy = TRUE,
  check_interrupt = TRUE,
  max_gen = -1,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
))
expect_error(BebelAsyncEventDrainOptions(max = -1))
