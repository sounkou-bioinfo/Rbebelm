# EmbeddingGemma encoding options

EmbeddingGemma encoding options

## Usage

``` r
EmbeddingGemmaOptions(
  text = character(0),
  task = character(0),
  title = NULL,
  dimensions = integer(0),
  normalize = logical(0),
  truncate = logical(0),
  check_interrupt = logical(0)
)
```

## Arguments

- text:

  Character vector to encode.

- task:

  Embedding task controlling the required model prompt.

- title:

  Optional document title, used only for `"retrieval_document"`.

- dimensions:

  Matryoshka output size: 768, 512, 256, or 128.

- normalize:

  Whether to L2-normalize each embedding.

- truncate:

  Whether to truncate inputs exceeding the 2048-token context.

- check_interrupt:

  Whether to poll R interrupts during tokenization and between bounded
  packed inference batches.
