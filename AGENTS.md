# AGENTS.md

This package is a thin R/savvy surface over upstream
[`maximecb/bebelm`](https://github.com/maximecb/bebelm). Keep it small:
native model loading, tokenization, embeddings, generation, persistent agents,
R tool calls, async jobs, and backend diagnostics.

## Architecture Rules

- The Rust backend owns BebeLM integration. R should expose typed calls and
  printers, not a second agent framework.
- `BebelModel` instances load GGUF weights once. `BebelAgent` instances keep
  independent transcript/decode state and share the model weights through the
  Rust backend.
- Async APIs return `BebelAsyncJob` objects. They must not call R callbacks from
  worker threads.
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
  calls when `BEBELM_WEIGHTS_FILE` points to a local GGUF file.
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
BEBELM_WEIGHTS_FILE=/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf make rdm
```

Install and test:

```sh
make dev-install
BEBELM_WEIGHTS_FILE=/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf \
  Rscript -e 'tinytest::test_package("Rbebelm")'
```

Full check:

```sh
BEBELM_WEIGHTS_FILE=/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf make check
```
