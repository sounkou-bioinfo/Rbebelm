# Generate EmbeddingGemma text embeddings

Runs the retrieval-trained bidirectional Gemma encoder, attention-mask
mean pooling, and both learned dense projection layers. The requested
task is deliberately mandatory: EmbeddingGemma was trained with
different prompt contracts for queries, documents, semantic similarity,
and other tasks.

## Usage

``` r
embeddinggemma_embed(
  model,
  text,
  task,
  title = NULL,
  dimensions = 768L,
  normalize = TRUE,
  truncate = TRUE,
  check_interrupt = TRUE
)
```

## Arguments

- model:

  An `EmbeddingGemmaModel` object.

- text:

  Character vector to embed.

- task:

  One of `"retrieval_query"`, `"retrieval_document"`,
  `"question_answering"`, `"fact_verification"`, `"classification"`,
  `"clustering"`, `"semantic_similarity"`, `"code_retrieval"`,
  `"summarization"`, or `"raw"`. `"raw"` adds no task prompt and should
  only be used with already formatted model input.

- title:

  Optional document-title scalar or vector. It is valid only for
  `task = "retrieval_document"`; `NULL` uses the model's `"none"` title.

- dimensions:

  Output dimension: 768, 512, 256, or 128.

- normalize:

  L2-normalize each output row. Keep this `TRUE` for cosine similarity
  and Matryoshka embeddings.

- truncate:

  Truncate overlong inputs to the model's 2048-token context, preserving
  BOS and EOS. If `FALSE`, overlong inputs fail.

- check_interrupt:

  Poll for R user interrupts during tokenization and between bounded
  packed inference batches.

## Value

An `embeddingGemmaEmbeddings` numeric matrix with one row per input. Its
`embedding_info` attribute records prompts, token counts, truncation,
dimensions, and normalization.

## Details

For retrieval, prefer
[`embeddinggemma_embed_query()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/embeddinggemma_embed_query.md)
and
[`embeddinggemma_embed_document()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/embeddinggemma_embed_document.md)
so query and document prompts cannot be confused. Matryoshka dimensions
512, 256, and 128 select the leading dimensions of the 768-vector and
then re-normalize, as specified by the model card.
