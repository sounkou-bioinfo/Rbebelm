# Encode a retrieval query with ColBERT

Applies the profile's required `[Q] ` prefix, encodes exactly 32 query
positions (including learned PAD expansion positions), projects them to
L2-normalized 128-dimensional token vectors, and returns a
`ColbertEmbeddings` handle.

## Usage

``` r
colbert_encode_query(model, text)
```

## Arguments

- model:

  A `ColbertModel` object.

- text:

  A non-empty query string.

## Value

A query `ColbertEmbeddings` object.
