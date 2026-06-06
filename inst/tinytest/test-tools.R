library(Rbebelm)

call <- bebel_parse_tool_call('echo({"x": 1})')
expect_equal(call$name, "echo")

ctx <- new.env(parent = emptyenv())
ctx$log <- character()
tool <- bebel_tool("echo", function(args, context, call) {
  context$log <- c(context$log, call$name)
  args
})
expect_true(inherits(tool, "bebelTool"))
out <- Rbebelm:::invoke_bebel_tool(tool, list(name = "echo", arguments = list(x = 1)), ctx)
expect_equal(out$x, 1)
expect_equal(ctx$log, "echo")

seen <- character()
Rbebelm:::call_bebel_hook(list(tool_request = function(call, ...) seen <<- call$name), "tool_request", call = list(name = "echo"))
expect_equal(seen, "echo")
