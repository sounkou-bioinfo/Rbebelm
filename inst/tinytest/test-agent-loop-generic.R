library(Rbebelm)

FakeBebelAgentBackendS3 <- S7::new_S3_class("fakeBebelAgentBackend")

S7::method(bebel_backend_append_user, FakeBebelAgentBackendS3) <- function(agent, message) {
  agent$user <- c(agent$user, message)
  agent
}
S7::method(bebel_backend_append_system, FakeBebelAgentBackendS3) <- function(agent, message, tools = NULL) {
  agent$system <- c(agent$system, message)
  agent
}
S7::method(bebel_backend_append_tool_result, FakeBebelAgentBackendS3) <- function(agent, content) {
  agent$tool <- c(agent$tool, content)
  agent
}
S7::method(bebel_backend_assistant_turn, FakeBebelAgentBackendS3) <- function(agent, on_event = NULL, check_interrupt = TRUE, stop_on_tool_call = FALSE) {
  if (!is.null(on_event)) on_event(list(type = "text", content = "fake reply"))
  list(text = "fake reply", tokens = 2L, stop = "stop")
}
S7::method(bebel_backend_info, FakeBebelAgentBackendS3) <- function(agent) list(provider = "fake", model = "fake-model")
S7::method(bebel_backend_transcript, FakeBebelAgentBackendS3) <- function(agent) paste(c(agent$system, agent$user, agent$tool), collapse = "\n")
S7::method(bebel_backend_clear, FakeBebelAgentBackendS3) <- function(agent) {
  agent$user <- character()
  agent$tool <- character()
  agent
}

backend <- structure(new.env(parent = emptyenv()), class = "fakeBebelAgentBackend")
backend$user <- character()
backend$tool <- character()
backend$system <- character()

tmp <- tempfile("loop-session-")
dir.create(tmp)
session <- bebel_session_create(cwd = tmp, session_dir = tmp)
loop <- bebel_agent_loop(backend, session = session)
run <- bebel_loop_run(loop, "hello", max_steps = 1L)
expect_true(isTRUE(run$done))
expect_equal(backend$user, "hello")
expect_equal(bebel_loop_state(loop)$session_file, bebel_session_file(session))

roles <- vapply(bebel_session_context(session)$messages, `[[`, character(1), "role")
expect_equal(roles, c("user", "assistant"))
expect_true(file.exists(bebel_session_file(session)))
