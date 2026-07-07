library(Rbebelm)

weights <- Sys.getenv("BEBELM_WEIGHTS_FILE", "/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf")
expect_true(file.exists(weights))
threads <- as.integer(Sys.getenv("BEBELM_TEST_NUM_THREADS", Sys.getenv("BEBELM_NUM_THREADS", "2")))
if (is.na(threads) || threads < 1L) threads <- 2L

model <- bebel_model_load(weights, num_threads = threads)
expect_true(inherits(model, "BebelModel"))

tokens <- bebel_tokenize(model, "Bamako", add_bos = FALSE)
expect_true(length(tokens) > 0L)
expect_true(nzchar(bebel_detokenize(model, tokens)))

emb <- bebel_embed(model, c(mali = "Mali capital", italy = "Italy capital"))
expect_equal(nrow(emb), 2L)
expect_true(ncol(emb) > 0L)
expect_true(all(is.finite(emb)))

emb_chunk1 <- bebel_embed(model, c("Mali capital", "Italy capital"), token_batch_size = 1L)
emb_chunk8 <- bebel_embed(model, c("Mali capital", "Italy capital"), token_batch_size = 8L)
expect_equal(dim(emb_chunk1), dim(emb_chunk8))
expect_true(max(abs(emb_chunk1 - emb_chunk8)) < 1e-6)

emb_seq1 <- bebel_embed(
  model,
  c("Mali capital", "Italy capital", "Japan capital"),
  token_batch_size = 1L,
  sequence_batch_size = 1L
)
emb_seq8 <- bebel_embed(
  model,
  c("Mali capital", "Italy capital", "Japan capital"),
  token_batch_size = 1L,
  sequence_batch_size = 8L
)
expect_equal(dim(emb_seq1), dim(emb_seq8))
expect_true(max(abs(emb_seq1 - emb_seq8)) < 1e-6)

direct_batch <- model$embed_batch(
  c("Mali capital", "Italy capital"),
  add_bos = TRUE,
  normalize = TRUE,
  pooling = "mean",
  check_interrupt = TRUE,
  token_batch_size = 8,
  sequence_batch_size = 8
)
expect_equal(dim(direct_batch), dim(emb_chunk8))
expect_true(max(abs(direct_batch - emb_chunk8)) < 1e-6)

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
expect_true(bebel_async_poll(job) %in% c("pending", "ready"))
async <- bebel_async_collect(job, wait = TRUE)
expect_true(inherits(async, "bebelGeneration"))
expect_true(nzchar(async$text))
first_events <- bebel_async_events(job, max = 2)
expect_equal(length(first_events), 2L)
remaining_events <- bebel_async_events(job)
event_types <- vapply(c(first_events, remaining_events), `[[`, character(1), "type")
expect_true("start" %in% event_types)
expect_true("text_delta" %in% event_types)
expect_true("done" %in% event_types)
expect_equal(length(bebel_async_events(job)), 0L)

wait_events <- character()
wait_job <- bebel_generate_async(
  model,
  "The capital of Germany is",
  greedy = TRUE,
  max_gen = 6,
  max_think = 0
)
waited <- bebel_async_wait(
  wait_job,
  on_event = function(event) wait_events <<- c(wait_events, event$type),
  poll_interval = 0
)
expect_true(inherits(waited, "bebelGeneration"))
expect_true("done" %in% wait_events)

cancel_job <- bebel_generate_async(
  model,
  "Count upward forever: one, two, three,",
  greedy = TRUE,
  max_gen = 256,
  max_think = 0
)
expect_true(isTRUE(bebel_async_cancel(cancel_job)))
expect_error(bebel_async_collect(cancel_job, wait = TRUE), "cancelled")

agent_job <- bebel_assistant_turn_async(agent)
agent_async <- bebel_async_collect(agent_job, wait = TRUE)
expect_true(inherits(agent_async, "bebelGeneration"))
expect_true(nzchar(agent_async$text))
agent_event_types <- vapply(bebel_async_events(agent_job), `[[`, character(1), "type")
expect_true("done" %in% agent_event_types)

jobs <- lapply(
  c("The capital of Mali is", "The capital of Italy is", "The capital of Japan is"),
  function(prompt) {
    bebel_generate_async(model, prompt, greedy = TRUE, max_gen = 6, max_think = 0)
  }
)
expect_true(all(vapply(jobs, function(job) bebel_async_poll(job) %in% c("pending", "ready"), logical(1))))
many_async <- lapply(jobs, bebel_async_collect, wait = TRUE)
expect_true(all(vapply(many_async, function(out) inherits(out, "bebelGeneration"), logical(1))))
expect_true(all(vapply(many_async, function(out) nzchar(out$text), logical(1))))

bench <- bebel_benchmark_generation(
  model,
  c("The capital of Mali is", "The capital of Italy is"),
  concurrency = 2L,
  repeats = 1L,
  greedy = TRUE,
  max_gen = 4L,
  max_think = 0L,
  poll_interval = 0
)
expect_true(inherits(bench, "bebelGenerationBenchmark"))
expect_equal(nrow(bench$jobs), 2L)
expect_equal(bench$aggregate$job_count, 2L)
expect_true(bench$aggregate$total_generated_tokens > 0)
expect_true(all(bench$jobs$event_count > 0))
