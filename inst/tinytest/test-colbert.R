library(Rbebelm)

weights <- Sys.getenv(
  "COLBERT_WEIGHTS_FILE",
  "/root/bebelm/LFM2.5-ColBERT-350M-Q4_K_M.gguf"
)
if (!file.exists(weights)) exit_file("COLBERT_WEIGHTS_FILE does not point to a local GGUF")
threads <- as.integer(Sys.getenv("BEBELM_TEST_NUM_THREADS", Sys.getenv("BEBELM_NUM_THREADS", "2")))
if (is.na(threads) || threads < 1L) threads <- 2L

model <- colbert_model_load(weights, num_threads = threads)
expect_true(inherits(model, "ColbertModel"))
info <- colbert_model_info(model)
expect_equal(info$architecture, "lfm2")
expect_equal(info$dimensions, 128L)
expect_equal(info$query_length, 32L)
expect_equal(info$document_length, 512L)
expect_equal(info$similarity, "MaxSim")

query <- colbert_encode_query(model, "What is panda?")
document <- colbert_encode_document(model, "It is a bear.")
expect_true(inherits(query, "ColbertEmbeddings"))
expect_true(inherits(document, "ColbertEmbeddings"))
expect_equal(colbert_embeddings_info(query)$tokens, 32L)
expect_equal(length(colbert_embedding_ids(query)), 32L)
query_vectors <- colbert_embedding_vectors(query)
document_vectors <- colbert_embedding_vectors(document)
expect_equal(ncol(query_vectors), 128L)
expect_equal(nrow(document_vectors), length(colbert_embedding_ids(document)))
expect_true(all(is.finite(query_vectors)))
expect_true(all(is.finite(document_vectors)))
expect_true(max(abs(sqrt(rowSums(query_vectors ^ 2)) - 1)) < 1e-5)
expect_true(max(abs(sqrt(rowSums(document_vectors ^ 2)) - 1)) < 1e-5)

score <- colbert_maxsim(query, document)
expect_true(is.finite(score))
expect_error(colbert_maxsim(document, query), "receiver must be query")

ranking <- colbert_rank(
  model,
  "What is panda?",
  c(
    greeting = "Hi!",
    bear = "It is a bear.",
    panda = "The giant panda is a bear species endemic to China."
  )
)
expect_true(inherits(ranking, "colbertRanking"))
expect_equal(length(ranking), 3L)
expect_true(all(is.finite(ranking)))
expect_true(identical(names(ranking), c("panda", "bear", "greeting")))
