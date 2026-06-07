library(Rbebelm)

e <- new.env(parent = baseenv())
e$x <- 1:3
td <- tempfile("rbebelm-agent-")
dir.create(td)
writeLines(c("alpha", "beta", "gamma alpha"), file.path(td, "a.txt"))

readonly_tools <- bebel_default_r_tools(env = e, cwd = td, allow_eval = FALSE, max_chars = 1000L)
expect_true(!"r_eval" %in% names(readonly_tools))
expect_true("r_objects" %in% names(readonly_tools))

out <- Rbebelm:::invoke_bebel_tool(
  readonly_tools$r_objects$tool,
  list(name = "r_objects", arguments = list()),
  new.env(parent = emptyenv())
)
expect_true(grepl("x:", out, fixed = TRUE))

tools <- bebel_default_r_tools(env = e, cwd = td, allow_eval = TRUE, max_chars = 1000L)
expect_true(all(c("r_objects", "r_eval", "r_help", "list_files", "read_file", "grep_files") %in% names(tools)))
expect_true(all(vapply(tools, inherits, logical(1), "bebelAgentTool")))

catalog <- bebel_agent_tool_catalog(tools)
expect_true(is.data.frame(catalog))
expect_true("r_eval" %in% catalog$name)
expect_true(grepl("tool_call_start", Rbebelm:::bebel_agent_tools_prompt(tools), fixed = TRUE))

ctx <- new.env(parent = emptyenv())
out <- Rbebelm:::invoke_bebel_tool(
  tools$r_eval$tool,
  list(name = "r_eval", arguments = list(code = "sum(x)")),
  ctx
)
expect_true(grepl("6", out, fixed = TRUE))

out <- Rbebelm:::invoke_bebel_tool(
  tools$read_file$tool,
  list(name = "read_file", arguments = list(path = "a.txt", from = 2L, lines = 1L)),
  ctx
)
expect_true(grepl("2 | beta", out, fixed = TRUE))

out <- Rbebelm:::invoke_bebel_tool(
  tools$grep_files$tool,
  list(name = "grep_files", arguments = list(pattern = "alpha", path = ".")),
  ctx
)
expect_true(grepl("a.txt:1", out, fixed = TRUE))
expect_true(grepl("a.txt:3", out, fixed = TRUE))

schema <- Rbebelm:::bebel_agent_tool_schema(tools$read_file$params)
expect_equal(schema$type, "object")
expect_true("path" %in% unlist(schema$required))

expect_true(Rbebelm:::bebel_console_input_complete("x <- 1"))
expect_false(Rbebelm:::bebel_console_input_complete("if (TRUE) {"))
Rbebelm:::bebel_console_eval_r(parse(text = "y <- sum(x)"), e)
expect_equal(e$y, 6L)

resp <- Rbebelm:::bebel_rpc_response(1L, result = list(ok = TRUE))
expect_equal(resp$jsonrpc, "2.0")
expect_true(resp$result$ok)

unlink(td, recursive = TRUE)
