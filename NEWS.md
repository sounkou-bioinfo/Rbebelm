# Rbebelm 0.3.6-0.1.0

- Fixed AArch64 scalar and NEON artifacts to avoid dot-product instructions;
  the dot-product artifact alone is compiled with that CPU feature. Added an
  AArch64 cross-build check for all runtime-dispatch variants.
- Exposed the existing `"dotprod"` backend as an explicit R selection.
- Refocused the package on native BebeLM model loading, tokenization, embeddings,
  generation, persistent agents, R tool calls, and async jobs.
- Removed the R-side agent framework, interactive frontend, session tree, extension
  layer, provider registry, and fuzzy-file-search code.
- Added S7 classes with property validators for model options, agent options,
  generation options, embedding options, tool specs, and native pointer refs.
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
- Moved pooled embeddings onto Rust batched paths: long texts use token-chunk
  prefill batching, and text vectors use independent sequence batching so short
  ontology labels can share batched matmul work. `bebel_embed()` exposes
  `token_batch_size` and `sequence_batch_size`.
- Kept batched embeddings memory-bounded by processing text chunks to completion
  with at most `sequence_batch_size` live sequence caches.

# Rbebelm 0.0.0.9000

- Initial experimental scaffold.
