# Create a native fuzzy file finder

`bebel_file_finder()` creates a persistent native FFF/`fff-c`-based file
index for a project directory. `bebel_file_search()` queries that index
and returns a data frame suitable for consoles, RPC clients, and the
standalone `tui/` file picker.

## Usage

``` r
bebel_file_finder(
  root = getwd(),
  frecency_db_path = "",
  history_db_path = "",
  enable_mmap_cache = FALSE,
  enable_content_indexing = FALSE,
  watch = FALSE,
  ai_mode = TRUE,
  wait_timeout_ms = 10000
)

bebel_file_search(
  finder = getwd(),
  query = "",
  current_file = "",
  max_threads = 0,
  offset = 0,
  limit = 50,
  combo_boost_score_multiplier = 100,
  min_combo_count = 3,
  wait_timeout_ms = 10000
)
```

## Arguments

- root:

  Project directory to index.

- frecency_db_path:

  Optional FFF frecency database path. Empty string disables frecency
  persistence.

- history_db_path:

  Optional FFF query-history database path. Empty string disables
  query-history persistence.

- enable_mmap_cache:

  Enable FFF mmap cache warmup.

- enable_content_indexing:

  Enable FFF content indexing.

- watch:

  Start FFF's filesystem watcher for live updates.

- ai_mode:

  Use FFF's AI-agent mode.

- wait_timeout_ms:

  Milliseconds to wait for initial indexing or query readiness.

- finder:

  A `BebelFileFinder` object, or a root path from which a temporary
  finder should be created for one search.

- query:

  Fuzzy query string.

- current_file:

  Optional currently focused file for FFF scoring.

- max_threads:

  Maximum FFF search threads; `0` means auto.

- offset:

  Result offset for pagination.

- limit:

  Maximum number of rows to return.

- combo_boost_score_multiplier:

  FFF combo boost multiplier.

- min_combo_count:

  Minimum combo count before boost.

## Value

A `BebelFileFinder` object.

## Details

The FFF backend is native-only. In webR/wasm this API is present but
creating a finder raises an explicit unsupported error so the rest of
the package can still load.
