# Tokenize EmbeddingGemma model input

Applies the same mandatory task formatting as
[`embeddinggemma_embed()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/embeddinggemma_embed.md)
and returns the exact BOS/content/EOS token sequence consumed by the
encoder.

## Usage

``` r
embeddinggemma_tokenize(model, text, task, title = NULL, truncate = TRUE)
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

- truncate:

  Truncate overlong inputs to the model's 2048-token context, preserving
  BOS and EOS. If `FALSE`, overlong inputs fail.

## Value

A named list containing integer `ids`, legible token pieces, the
task-formatted text, and a truncation flag.
