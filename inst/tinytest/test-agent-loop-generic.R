library(Rbebelm)

FakeAgentBackendS3 <- S7::new_S3_class("fakeAgentBackend")

S7::method(agent_append_user, FakeAgentBackendS3) <- function(agent, message) {
  agent$user <- c(agent$user, message)
  agent
}
S7::method(agent_append_system, FakeAgentBackendS3) <- function(agent, message, tools = NULL) {
  agent$system <- c(agent$system, message)
  agent
}
S7::method(agent_append_tool_result, FakeAgentBackendS3) <- function(agent, content) {
  agent$tool <- c(agent$tool, content)
  agent
}
S7::method(agent_assistant_turn, FakeAgentBackendS3) <- function(agent, on_event = NULL, check_interrupt = TRUE, stop_on_tool_call = FALSE) {
  if (!is.null(on_event)) on_event(list(type = "text", content = "fake reply"))
  list(text = "fake reply", tokens = 2L, stop = "stop")
}
S7::method(agent_info, FakeAgentBackendS3) <- function(agent) list(provider = "fake", model = "fake-model")
S7::method(agent_transcript, FakeAgentBackendS3) <- function(agent) paste(c(agent$system, agent$user, agent$tool), collapse = "\n")
S7::method(agent_clear, FakeAgentBackendS3) <- function(agent) {
  agent$user <- character()
  agent$tool <- character()
  agent
}

backend <- structure(new.env(parent = emptyenv()), class = "fakeAgentBackend")
backend$user <- character()
backend$tool <- character()
backend$system <- character()

tmp <- tempfile("loop-session-")
dir.create(tmp)
session <- agent_session_create(cwd = tmp, session_dir = tmp)
loop <- bebel_agent_loop(backend, session = session)
run <- bebel_loop_run(loop, "hello", max_steps = 1L)
expect_true(isTRUE(run$done))
expect_equal(backend$user, "hello")
expect_equal(bebel_loop_state(loop)$session_file, agent_session_file(session))

roles <- vapply(agent_session_context(session)$messages, `[[`, character(1), "role")
expect_equal(roles, c("user", "assistant"))
expect_true(file.exists(agent_session_file(session)))
