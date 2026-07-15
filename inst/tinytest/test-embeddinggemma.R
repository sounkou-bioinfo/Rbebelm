library(Rbebelm)

weights <- Sys.getenv(
  "EMBEDDING_GEMMA_WEIGHTS_FILE",
  "/root/bebelm/embeddinggemma-300M-Q8_0.gguf"
)
expect_true(file.exists(weights))
threads <- as.integer(Sys.getenv("BEBELM_TEST_NUM_THREADS", Sys.getenv("BEBELM_NUM_THREADS", "2")))
if (is.na(threads) || threads < 1L) threads <- 2L

model <- embeddinggemma_model_load(weights, num_threads = threads)
expect_true(inherits(model, "EmbeddingGemmaModel"))
info <- embeddinggemma_model_info(model)
expect_equal(info$architecture, "gemma-embedding")
expect_equal(info$context_length, 2048L)
expect_equal(info$dimensions, c(768L, 512L, 256L, 128L))

tokens <- embeddinggemma_tokenize(model, "capital of Mali", task = "retrieval_query")
expect_true(inherits(tokens, "embeddingGemmaTokens"))
expect_equal(
  tokens$ids,
  c(2L, 8071L, 236787L, 3927L, 1354L, 1109L, 7609L, 236787L, 5279L, 529L, 63037L, 1L)
)
expect_false(tokens$truncated)
expect_equal(tokens$text, "task: search result | query: capital of Mali")
multilingual_tokens <- embeddinggemma_tokenize(
  model,
  "東京は日本の首都ではない",
  task = "raw"
)
expect_equal(multilingual_tokens$ids, c(2L, 31414L, 237048L, 76444L, 120211L, 60486L, 1L))

query <- embeddinggemma_embed_query(model, "capital of Mali")
expect_true(inherits(query, "embeddingGemmaEmbeddings"))
expect_equal(dim(query), c(1L, 768L))
expect_true(all(is.finite(query)))
expect_true(abs(sqrt(sum(query ^ 2)) - 1) < 1e-6)
query_info <- attr(query, "embedding_info")
expect_equal(query_info$task, "retrieval_query")
expect_true(query_info$retrieval_trained)
expect_equal(query_info$token_count, 12L)
expect_false(query_info$truncated)

reference_path <- system.file(
  "tinytest", "fixtures", "embeddinggemma-query-reference.txt",
  package = "Rbebelm"
)
reference <- scan(reference_path, quiet = TRUE, comment.char = "#")
expect_equal(length(reference), 768L)
expect_true(sum(as.numeric(query) * reference) > 0.999)

documents <- c(
  mali = "Bamako is the capital and largest city of Mali.",
  italy = "Rome is the capital city of Italy.",
  desert = "The Sahara is a desert in northern Africa."
)
document_embeddings <- embeddinggemma_embed_document(model, documents)
expect_equal(dim(document_embeddings), c(3L, 768L))
expect_equal(rownames(document_embeddings), names(documents))
scores <- drop(document_embeddings %*% as.numeric(query))
expect_equal(names(which.max(scores)), "mali")

single_documents <- do.call(rbind, lapply(documents, function(document) {
  embeddinggemma_embed_document(model, document)
}))
expect_true(max(abs(unclass(document_embeddings) - unclass(single_documents))) < 1e-7)

# Cross the packed 512-token budget: chunking must preserve order and keep every
# sequence independent.
repeated_queries <- embeddinggemma_embed_query(model, rep("capital of Mali", 50L))
expect_equal(dim(repeated_queries), c(50L, 768L))
expect_true(max(abs(sweep(unclass(repeated_queries), 2L, repeated_queries[1L, ], "-"))) < 1e-7)
expect_equal(attr(repeated_queries, "embedding_info")$token_count, rep(12L, 50L))

embedding_256 <- embeddinggemma_embed_query(model, "capital of Mali", dimensions = 256L)
manual_256 <- as.numeric(query)[seq_len(256L)]
manual_256 <- manual_256 / sqrt(sum(manual_256 ^ 2))
expect_equal(dim(embedding_256), c(1L, 256L))
expect_true(max(abs(as.numeric(embedding_256) - manual_256)) < 1e-6)

semantic <- embeddinggemma_embed(
  model,
  c("A pleasant day", "Beautiful weather"),
  task = "semantic_similarity"
)
expect_equal(attr(semantic, "embedding_info")$task, "semantic_similarity")
expect_equal(dim(semantic), c(2L, 768L))

with_title <- embeddinggemma_embed_document(model, documents[[1L]], title = "Mali")
without_title <- embeddinggemma_embed_document(model, documents[[1L]])
expect_true(max(abs(with_title - without_title)) > 1e-6)

long_text <- paste(rep("token", 3000L), collapse = " ")
expect_error(embeddinggemma_tokenize(model, long_text, task = "retrieval_query", truncate = FALSE))
truncated_tokens <- embeddinggemma_tokenize(model, long_text, task = "retrieval_query")
expect_true(truncated_tokens$truncated)
expect_equal(length(truncated_tokens$ids), 2048L)
