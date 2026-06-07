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

fake_run <- list(
  turns = list(
    list(stop = "eos", prompt_tokens = 10L, generated_tokens = 5L, prefill_seconds = 1, decode_seconds = 0.5),
    list(stop = "max_new", prompt_tokens = 3L, generated_tokens = 2L, prefill_seconds = 0.5, decode_seconds = 0.25)
  ),
  tool_calls = list(list(name = "r_objects"))
)
stats <- Rbebelm:::bebel_agent_run_stats(fake_run)
expect_equal(stats$prompt_tokens, 13L)
expect_equal(stats$generated_tokens, 7L)
expect_equal(stats$tool_calls, 1L)
expect_true(grepl("decode=", Rbebelm:::bebel_format_agent_run_stats(fake_run), fixed = TRUE))

expect_true(Rbebelm:::bebel_console_input_complete("x <- 1"))
expect_false(Rbebelm:::bebel_console_input_complete("if (TRUE) {"))
Rbebelm:::bebel_console_eval_r(parse(text = "y <- sum(x)"), e)
expect_equal(e$y, 6L)
cap_out <- capture.output(Rbebelm:::bebel_console_print_capped(as.character(1:5), max_lines = 2L, max_chars = 100L))
expect_true(any(grepl("R output truncated", cap_out, fixed = TRUE)))
expect_true("1" %in% cap_out)
expect_true("2" %in% cap_out)
expect_true(!"5" %in% cap_out)

resp <- Rbebelm:::bebel_rpc_response(1L, result = list(ok = TRUE))
expect_equal(resp$jsonrpc, "2.0")
expect_true(resp$result$ok)

old_threads <- Sys.getenv("BEBELM_NUM_THREADS", unset = NA_character_)
Sys.setenv(BEBELM_NUM_THREADS = "2")
threads_default <- eval(formals(bebel_r_agent_start)$num_threads)
if (is.na(old_threads)) Sys.unsetenv("BEBELM_NUM_THREADS") else Sys.setenv(BEBELM_NUM_THREADS = old_threads)
expect_true(is.double(threads_default))
expect_equal(threads_default, 2)

agent_bin <- system.file("bin/rbebelm-agent", package = "Rbebelm")
expect_true(file.exists(agent_bin))
help_out <- system2(agent_bin, "--help", stdout = TRUE)
expect_true(any(grepl("Usage: rbebelm-agent", help_out, fixed = TRUE)))

unlink(td, recursive = TRUE)
