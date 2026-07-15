# Encode retrieval queries with EmbeddingGemma

Encode retrieval queries with EmbeddingGemma

## Usage

``` r
embeddinggemma_embed_query(
  model,
  text,
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
