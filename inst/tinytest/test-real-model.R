library(Rbebelm)

weights <- Sys.getenv("BEBELM_WEIGHTS_FILE")
if (!nzchar(weights) || !file.exists(weights)) {
  message("Skipping real-model tests; set BEBELM_WEIGHTS_FILE to a GGUF file.")
  expect_true(TRUE)
} else {
  model <- bebel_model_load(weights, num_threads = 2)

  events <- character()
  out <- bebel_generate(
    model,
    "The capital of France is",
    greedy = TRUE,
    max_gen = 8,
    max_think = 0,
    on_event = function(event) events <<- c(events, event$type),
    check_interrupt = TRUE
  )
  expect_true(grepl("Paris", out$text, ignore.case = TRUE))
  expect_true("start" %in% events)
  expect_true("text_delta" %in% events)
  expect_true("done" %in% events)

  agent <- bebel_agent(model, greedy = TRUE, max_gen = 8, max_think = 0)
  bebel_append(agent, "The capital of France is")
  turn <- bebel_agent_generate(agent, on_event = NULL)
  expect_true(grepl("Paris", turn$text, ignore.case = TRUE))
  info <- bebel_agent_info(agent)
  expect_true(info$history_tokens > 0L)
  expect_true(info$processed_tokens > 0L)
  expect_equal(bebel_history(agent), agent$history())
  expect_true(length(agent$history()) > 0L)
  expect_true(nzchar(agent$transcript()))
  expect_equal(bebel_transcript(agent), agent$transcript())

  reset <- agent$clear()
  expect_equal(reset$history_tokens, 0L)
  expect_equal(length(bebel_history(agent)), 0L)
  expect_identical(bebel_clear(agent)$history_tokens, 0L)

  bebel_append_user(agent, "And Italy?")
  turn2 <- bebel_assistant_turn(agent, on_event = NULL)
  expect_true(nzchar(turn2$text))
}
