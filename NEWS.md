# Rbebelm 0.2.0-0.1.0

- Added the standalone ARF-style `tui/` Rust module with TOML config, headless Rbebelm RPC hosting, a JSON-RPC client, and a minimal `crossterm`/`ratatui` chat frontend.
- Fixed the TUI so `/state` and cached `/help` remain responsive while a model turn is running, using the frontend's stream-observed loop state instead of waiting for the busy R command handler.
- Reordered README and getting-started documentation around clear entry points: generic framework, concrete local backend, native file search, and terminal frontend.
- Reoriented the package around the public `bebel_*` / `Bebel*` API for the generic R agent/frontend framework.
- Added S7/s7contract contracts for backends, extensions, skills, prompt templates, loop commands/events, and Pi-inspired JSONL session trees.
- Added native FFF-backed fuzzy file search through `bebel_file_finder()` and `bebel_file_search()` with explicit webR/wasm unsupported diagnostics.
- Hardened native SIMD dispatch: scalar builds use a baseline x86-64 target, optimized dylibs are selected by runtime CPU checks, and FFF/neo_frizbee SIMD remains runtime-gated.
- Updated webR packaging checks for hard runtime dependencies including S7, s7contract, and yyjsonr.

# Rbebelm 0.0.0.9000

- Initial experimental scaffold.
