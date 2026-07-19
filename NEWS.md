# Rbebelm 0.3.6-0.1.0

- Replaced the experimental causal contextual-state retrieval surface with a
  native, retrieval-trained LFM2.5-ColBERT-350M GGUF profile. New
  `colbert_*()` APIs own the published query/document prefixes, non-causal
  encoder, 128-dimensional L2-normalized token projection, punctuation
  filtering, and MaxSim scoring contract. `bebel_pooled_states()` and
  `bebel_token_states()` are removed: causal generator states are not a
  late-interaction retriever.
- Established the vendored BebeLM Rust backend as a closed, validated CPU
  profile registry rather than a generic GGUF loader. New model families add
  their own tensor contract and execution profile; BebeLM generation continues
  to support its LFM2.5-8B-A1B profile.
- Added a dedicated pure-Rust `gemma-embedding` backend for the 300M
  EmbeddingGemma GGUF architecture, including its SentencePiece tokenizer,
  bidirectional global/symmetric-window attention schedule, mean pooling, both
  learned dense projections, task-specific query/document prompts, L2
  normalization, and 768/512/256/128-dimensional Matryoshka outputs. Batches
  use bounded sequence packing without cross-sequence attention and parallel
  GeGLU evaluation. New `embeddinggemma_*()` APIs keep these retrieval-trained
  dense embeddings separate from BebeLM generation.
- Fixed AArch64 scalar and NEON artifacts to avoid dot-product instructions;
  the dot-product artifact alone is compiled with that CPU feature. Added an
  AArch64 cross-build check for all runtime-dispatch variants.
- Exposed the existing `"dotprod"` backend as an explicit R selection.
- Refocused the package on native BebeLM model loading, tokenization,
  retrieval-trained encoders, generation, persistent agents, R tool calls, and
  async jobs.
- Removed the R-side agent framework, interactive frontend, session tree, extension
  layer, provider registry, and fuzzy-file-search code.
- Added S7 classes with property validators for model options, agent options,
  generation options, tool specs, and native pointer refs.
- Added async model and agent generation through Rust worker threads. Jobs are
  represented as `BebelAsyncJob` objects and collected from R with
  `bebel_async_collect()`.
- Removed the model execution mutex so async jobs can run concurrently while
  sharing immutable memory-mapped weights and keeping independent caches.
- Surfaced the shared-weight model design: agents own transcript/decode state
  while sharing loaded GGUF weights through the Rust backend.
- Updated README, vignettes, pkgdown metadata, tinytests, and the webR
  package-load check around real BebeLM runs and the lean public API.
- Hardened native SIMD dispatch: scalar builds use a baseline target and
  optimized dylibs are selected by runtime CPU checks.

# Rbebelm 0.0.0.9000

- Initial experimental scaffold.
