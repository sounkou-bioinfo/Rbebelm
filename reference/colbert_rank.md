# Rank documents with ColBERT MaxSim

This convenience helper performs exact in-memory scoring. It is suitable
for a candidate set; production-scale retrieval needs an external late-
interaction index built with the same profile and preprocessing
contract.

## Usage

``` r
colbert_rank(model, query, documents)
```

## Arguments

- model:

  A `ColbertModel` object.

- query:

  A non-empty query string.

- documents:

  A non-empty character vector of candidate documents.

## Value

A decreasing named numeric vector of MaxSim scores with class
`colbertRanking`.
