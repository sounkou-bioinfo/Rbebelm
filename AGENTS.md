# AGENTS.md

This repository is both:

1. **A generic R agent/frontend framework**: backend-agnostic contracts, loop
   policy, event streams, tool dispatch, extension registration, skill and
   prompt-template providers, command catalogs for consoles/RPC/TUIs, and
   Pi-inspired append-only JSONL session trees.
2. **A concrete native backend**: R/savvy bindings to upstream
   [`maximecb/bebelm`](https://github.com/maximecb/bebelm) for local CPU GGUF
   inference, with runtime-selected Rust SIMD backends.

Keep those layers separate. The framework should not assume BebeLM internals;
BebeLM should implement the framework provider contracts.

## Architecture rules

- `AgentBackend` is the generic LLM-provider contract. BebeLM is one
  implementation, not the framework itself.
- `bebel_agent_loop()` owns lifecycle, queues, events, tool dispatch,
  extensions, and session persistence.
- Consoles, RPC handlers, and future TUIs consume the loop; they must not own or
  duplicate agent logic.
- Use Pi vocabulary for interactive queues: `steer`, `followUp`,
  `steering_mode`, and `follow_up_mode`.
- Extensions are backend-agnostic capability bundles registered into the loop.
  An extension should implement/provide:
  - manifest metadata,
  - tools,
  - commands,
  - hooks,
  - optional skill providers,
  - optional prompt-template providers,
  - optional UI metadata for frontend/TUI consumers.
- Skills and prompt templates are provider interfaces, not BebeLM-specific
  helpers.
- Session persistence is backend-agnostic JSONL under
  `tools::R_user_dir("Rbebelm", "data")/sessions/<encoded-cwd>/` unless
  overridden. Preserve tree semantics with `id`/`parentId` and append-only
  history.

## Documentation rules

- `README.md` is generated from `README.Rmd`; never hand-edit `README.md`.
- Raw/model-running documentation lives in `vignettes-raw/`.
- Precompiled/check-safe vignette sources live in `vignettes/`.
- If you update a raw vignette that is meant to ship, copy/regenerate the paired
  file under `vignettes/`.
- Documentation should present the package as a generic agent/frontend framework
  plus a concrete BebeLM backend.
- Do not run GGUF model inference during package install, check, or pkgdown.
  Guard model-running chunks with `BEBELM_WEIGHTS_FILE`.

## Dependency and platform rules

- JSON handling uses imported `yyjsonr`; do not reintroduce `jsonlite` or an ad
  hoc parser.
- Keep `nanonext`, `ellmer`, and `vitals` optional.
- Do not add TerminalR, rcurses, or eventloop as hard dependencies for the core
  framework.
- For a serious terminal TUI, prefer a separate Rust frontend using
  `crossterm`/`ratatui` that consumes loop/RPC/events.
- ARM baseline is NEON; dotprod is a separate runtime-selected backend.
- Windows targets the GNU Rust/Rtools path.

## Common workflows

Regenerate wrappers/docs:

```sh
make rd
```

Regenerate README from source, using the local real model only when explicitly
available:

```sh
BEBELM_WEIGHTS_FILE=/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf make rdm
```

Install and test:

```sh
make dev-install
Rscript -e 'tinytest::test_package("Rbebelm")'
```

Full check:

```sh
make check
```

Optional real-model smoke test:

```sh
BEBELM_WEIGHTS_FILE=/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf \
  Rscript -e 'tinytest::run_test_file("inst/tinytest/test-real-model.R")'
```

## Commit hygiene

- Keep generated `NAMESPACE`, `man/*.Rd`, and `README.md` in sync with source
  changes.
- Avoid committing generated whitespace-only changes in C dispatch files.
- Run at least tinytests for framework/API changes; run `make check` before
  pushing broad documentation/API changes.
