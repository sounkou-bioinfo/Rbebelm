# Rbebelm 0.2.0-0.1.0

- Refocused the package on native BebeLM model loading, tokenization, embeddings,
  generation, persistent agents, R tool calls, and async jobs.
- Removed the R-side agent framework, interactive frontend, session tree, extension
  layer, provider registry, and fuzzy-file-search code.
- Added S7 classes with property validators for model options, agent options,
  generation options, embedding options, tool specs, and native pointer refs.
- Added async model and agent generation through Rust worker threads. Jobs are
  represented as `BebelAsyncJob` objects and collected from R with
  `bebel_async_collect()`.
- Surfaced the shared-weight model design: agents own transcript/decode state
  while sharing loaded GGUF weights through the Rust backend.
- Updated README, vignettes, pkgdown metadata, tinytests, and the webR
  package-load check around real BebeLM runs and the lean public API.
- Hardened native SIMD dispatch: scalar builds use a baseline target and
  optimized dylibs are selected by runtime CPU checks.

# Rbebelm 0.0.0.9000

- Initial experimental scaffold.
