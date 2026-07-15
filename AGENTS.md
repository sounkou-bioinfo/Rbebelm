# AGENTS.md

This package is a thin R/savvy surface over upstream
[`maximecb/bebelm`](https://github.com/maximecb/bebelm), plus a small dedicated
pure-Rust EmbeddingGemma encoder. Keep it focused: native model loading,
tokenization, retrieval embeddings, contextual-state extraction, generation,
persistent agents, R tool calls, async jobs, and backend diagnostics.

## Architecture Rules

- The Rust backend owns model integration. R should expose typed calls and
  printers, not a second agent or inference framework.
- Keep EmbeddingGemma stateless and separate from `BebelModel`: its Rust crate
  owns GGUF validation, SentencePiece tokenization, bidirectional attention,
  mean pooling, learned projections, and Matryoshka truncation. Validate it
  against a pinned external oracle without linking that oracle into the package.
- `BebelModel` instances load GGUF weights once. `BebelAgent` instances keep
  independent transcript/decode state and share the model weights through the
  Rust backend.
- Async APIs return `BebelAsyncJob` objects. Rust workers may enqueue plain
  generation events; R drains them from the main thread with
  `bebel_async_events()`. R tool execution also belongs on the R main thread.
- Tools are `BebelToolSpec` S7 objects. Keep validation in S7 properties and
  validators instead of adding checker helper functions.
- JSON handling uses imported `yyjsonr`.
- Preserve webR loadability. Unsupported native inference should fail at model
  loading with a useful error, not at package load.
- Be strict about SIMD dispatch. Portable/scalar artifacts must not be compiled
  with unguarded native CPU assumptions.

## Documentation Rules

- `README.md` is generated from `README.Rmd`; never hand-edit it.
- README and vignettes are executable examples. They should run real BebeLM
  calls when `BEBELM_WEIGHTS_FILE` points to a local GGUF file and real
  EmbeddingGemma calls when `EMBEDDING_GEMMA_WEIGHTS_FILE` is set.
- Do not add fake examples or guard whole documents into inert prose.
- Keep generated `NAMESPACE`, `man/*.Rd`, and `README.md` in sync with source
  changes.

## Common Workflows

Regenerate wrappers and docs:

```sh
make rd
```

Regenerate README from source:

```sh
BEBELM_WEIGHTS_FILE=/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf \
EMBEDDING_GEMMA_WEIGHTS_FILE=/root/bebelm/embeddinggemma-300M-Q8_0.gguf \
  make rdm
```

Install and test:

```sh
make dev-install
BEBELM_WEIGHTS_FILE=/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf \
EMBEDDING_GEMMA_WEIGHTS_FILE=/root/bebelm/embeddinggemma-300M-Q8_0.gguf \
  Rscript -e 'tinytest::test_package("Rbebelm")'
```

Full check:

```sh
BEBELM_WEIGHTS_FILE=/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf \
EMBEDDING_GEMMA_WEIGHTS_FILE=/root/bebelm/embeddinggemma-300M-Q8_0.gguf \
  make check
```
