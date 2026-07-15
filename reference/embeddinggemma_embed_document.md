# Encode retrieval documents with EmbeddingGemma

Encode retrieval documents with EmbeddingGemma

## Usage

``` r
embeddinggemma_embed_document(
  model,
  text,
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

An `embeddingGemmaEmbeddings` numeric matrix.
