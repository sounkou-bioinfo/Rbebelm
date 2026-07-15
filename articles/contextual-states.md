# Contextual states and retrieval boundaries

``` r

library(Rbebelm)
weights_file <- Sys.getenv("BEBELM_WEIGHTS_FILE", "/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf")
stopifnot(file.exists(weights_file))
model <- bebel_model_load(weights_file, num_threads = 2)
```

## What the package extracts

LFM2.5-8B-A1B is a causal text-generation model. `Rbebelm` can expose
useful intermediate features from it, but does not call those features
semantic embeddings.

For every token,
[`bebel_token_states()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_token_states.md):

1.  runs the normal causal model, so a token sees itself and only its
    left context;
2.  takes the residual state after the last transformer layer;
3.  applies `token_embd_norm`, the model’s final RMSNorm used
    immediately before the tied vocabulary projection; and
4.  optionally L2-normalizes that token row.

``` r

tokens <- bebel_token_states(model, "Bamako is the capital of Mali")
tokens
```

    ## <BebeLM token contextual states>
    ##   tokens: 8
    ##   dimensions: 2048
    ##   final model norm: yes
    ##   L2 normalized: yes
    ##   retrieval trained: no

``` r

head(data.frame(
  index = tokens$token_index,
  id = tokens$ids,
  token = tokens$tokens
))
```

    ##   index   id    token
    ## 1     0   42        B
    ## 2     1  330       am
    ## 3     2 6261      ako
    ## 4     3  355       is
    ## 5     4  278      the
    ## 6     5 5205  capital

[`bebel_pooled_states()`](https://sounkou-bioinfo.github.io/Rbebelm/reference/bebel_pooled_states.md)
pools the post-final-norm token states. Its default `"weighted_mean"`
mode uses weights `1, 2, ..., n`, then L2-normalizes the result. Giving
later causal states more weight follows the pooling baseline in SGPT,
where later states have observed more of the sequence.

``` r

states <- bebel_pooled_states(model, c(
  mali = "Bamako is the capital of Mali.",
  italy = "Rome is the capital of Italy."
))
states
```

    ## <BebeLM pooled contextual states>
    ##   rows: 2
    ##   dimensions: 2048
    ##   pooling: weighted_mean
    ##   final model norm: yes
    ##   L2 normalized: yes
    ##   retrieval trained: no

``` r

attr(states, "state_info")
```

    ## $source_task
    ## [1] "causal language modeling"
    ## 
    ## $final_norm
    ## [1] TRUE
    ## 
    ## $l2_normalized
    ## [1] TRUE
    ## 
    ## $add_bos
    ## [1] TRUE
    ## 
    ## $pooling
    ## [1] "weighted_mean"
    ## 
    ## $retrieval_trained
    ## [1] FALSE

The extraction contract is explicit in `state_info`. In particular,
`retrieval_trained` is `FALSE`.

## What this does not establish

A mathematically valid cosine or MaxSim calculation is not evidence of a
valid retriever. The LFM weights have no contrastive retrieval
objective, no trained query/document encoding policy, and no
late-interaction projection or compression head. Consequently:

- cosine values from pooled states are uncalibrated;
- nearest-neighbor rankings can follow lexical or positional artifacts;
- raw token-state MaxSim can rank distractors above relevant passages;
  and
- adding natural-language instructions does not substitute for retrieval
  training and held-out evaluation.

The following computes the ColBERT-style *shape* of a late interaction
for inspection only. It is deliberately not exported as a retrieval API.

``` r

query <- bebel_token_states(model, "capital of Mali")$states
passage <- bebel_token_states(model, "Bamako is the capital of Mali")$states
similarity <- query %*% t(passage)
diagnostic_maxsim <- sum(apply(similarity, 1L, max))
diagnostic_maxsim
```

    ## [1] 1.136907

## A path to a real retriever

For supported dense retrieval, `Rbebelm` now provides a separate
`EmbeddingGemmaModel` and query/document encoding API. That model has
bidirectional attention, learned projections, explicit prompts, and a
contrastive retrieval objective; none of those properties transfer to
the raw LFM states discussed here.

Turning these primitives into a supported retriever requires a
separately versioned, retrieval-trained artifact and evidence for its
contract:

1.  choose dense pooling or a late-interaction projection;
2.  train on query-positive-negative examples with an appropriate
    contrastive or ranking loss;
3.  define query and document formatting, special-token filtering,
    dimensions, and normalization as model metadata;
4.  evaluate held-out retrieval datasets, hard negatives, languages, and
    target domains against established embedding baselines; and
5.  only then expose an index/scoring API tied to that trained artifact.

Precedents include SGPT for weighted pooling of decoder states, LLM2Vec
and NV-Embed for adapting decoder-only models into encoders, and ColBERT
for trained token-level late interaction. Those systems support the
direction, but they do not validate raw LFM states by themselves.

## References

- Muennighoff (2022), [SGPT: GPT Sentence Embeddings for Semantic
  Search](https://arxiv.org/abs/2202.08904).
- BehnamGhader et al. (2024),
  [LLM2Vec](https://arxiv.org/abs/2404.05961).
- Lee et al. (2024), [NV-Embed](https://arxiv.org/abs/2405.17428).
- Khattab and Zaharia (2020),
  [ColBERT](https://arxiv.org/abs/2004.12832).
