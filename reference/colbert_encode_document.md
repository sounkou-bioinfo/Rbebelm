# Encode a retrieval document with ColBERT

Applies the profile's required `[D] ` prefix, encodes up to 512
positions, projects them to L2-normalized token vectors, then removes
only the profile's published punctuation skip-list from the scoring
vectors.

## Usage

``` r
colbert_encode_document(model, text)
```

## Arguments

- model:

  A `ColbertModel` object.

- text:

  A non-empty document string.

## Value

A document `ColbertEmbeddings` object.
