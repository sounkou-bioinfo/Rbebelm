library(Rbebelm)

weights <- Sys.getenv("BEBELM_WEIGHTS_FILE", "/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf")
expect_true(file.exists(weights))

model <- bebel_model_load(weights, num_threads = 2)
expect_true(inherits(model, "BebelModel"))

tokens <- bebel_tokenize(model, "Bamako", add_bos = FALSE)
expect_true(length(tokens) > 0L)
expect_true(nzchar(bebel_detokenize(model, tokens)))

emb <- bebel_embed(model, c(mali = "Mali capital", italy = "Italy capital"))
expect_equal(nrow(emb), 2L)
expect_true(ncol(emb) > 0L)
expect_true(all(is.finite(emb)))

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

system_agent <- bebel_agent(model)
bebel_append_system(system_agent, "You are concise.")
raw_system_agent <- bebel_agent(model)
bebel_append(raw_system_agent, "<|im_start|>system\nYou are concise.<|im_end|>\n")
expect_equal(bebel_transcript(system_agent), bebel_transcript(raw_system_agent))
expect_true(grepl("<\\|im_start\\|>system", bebel_transcript(system_agent)))

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

bebel_append_user(agent, "Name one city in Italy.")
turn2 <- bebel_assistant_turn(agent, on_event = NULL)
expect_true(nzchar(turn2$text))

job <- bebel_generate_async(
  model,
  "The capital of Italy is",
  greedy = TRUE,
  max_gen = 6,
  max_think = 0
)
expect_true(inherits(job, "BebelAsyncJob"))
async <- bebel_async_result(job, wait = TRUE)
expect_true(inherits(async, "bebelGeneration"))
expect_true(nzchar(async$text))

agent_job <- bebel_assistant_turn_async(agent)
agent_async <- bebel_async_result(agent_job, wait = TRUE)
expect_true(inherits(agent_async, "bebelGeneration"))
expect_true(nzchar(agent_async$text))
