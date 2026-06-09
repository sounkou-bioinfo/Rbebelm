#' Create a native fuzzy file finder
#'
#' `bebel_file_finder()` creates a persistent native FFF/`fff-c`-based file
#' index for a project directory. `bebel_file_search()` queries that index and
#' returns a data frame suitable for consoles, RPC clients, and the standalone
#' `tui/` file picker.
#'
#' The FFF backend is native-only. In webR/wasm this API is present but creating
#' a finder raises an explicit unsupported error so the rest of the package can
#' still load.
#'
#' @param root Project directory to index.
#' @param frecency_db_path Optional FFF frecency database path. Empty string
#'   disables frecency persistence.
#' @param history_db_path Optional FFF query-history database path. Empty string
#'   disables query-history persistence.
#' @param enable_mmap_cache Enable FFF mmap cache warmup.
#' @param enable_content_indexing Enable FFF content indexing.
#' @param watch Start FFF's filesystem watcher for live updates.
#' @param ai_mode Use FFF's AI-agent mode.
#' @param wait_timeout_ms Milliseconds to wait for initial indexing or query
#'   readiness.
#' @return A `BebelFileFinder` object.
#' @export
bebel_file_finder <- function(
  root = getwd(),
  frecency_db_path = "",
  history_db_path = "",
  enable_mmap_cache = FALSE,
  enable_content_indexing = FALSE,
  watch = FALSE,
  ai_mode = TRUE,
  wait_timeout_ms = 10000
) {
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  BebelFileFinder$new(
    root,
    as.character(frecency_db_path %||% ""),
    as.character(history_db_path %||% ""),
    isTRUE(enable_mmap_cache),
    isTRUE(enable_content_indexing),
    isTRUE(watch),
    isTRUE(ai_mode),
    as.numeric(wait_timeout_ms)
  )
}

#' @rdname bebel_file_finder
#' @param finder A `BebelFileFinder` object, or a root path from which a
#'   temporary finder should be created for one search.
#' @param query Fuzzy query string.
#' @param current_file Optional currently focused file for FFF scoring.
#' @param max_threads Maximum FFF search threads; `0` means auto.
#' @param offset Result offset for pagination.
#' @param limit Maximum number of rows to return.
#' @param combo_boost_score_multiplier FFF combo boost multiplier.
#' @param min_combo_count Minimum combo count before boost.
#' @export
bebel_file_search <- function(
  finder = getwd(),
  query = "",
  current_file = "",
  max_threads = 0,
  offset = 0,
  limit = 50,
  combo_boost_score_multiplier = 100,
  min_combo_count = 3,
  wait_timeout_ms = 10000
) {
  if (is.character(finder) && length(finder) == 1L) {
    finder <- bebel_file_finder(finder, wait_timeout_ms = wait_timeout_ms)
  }
  if (!inherits(finder, "Rbebelm::BebelFileFinder")) {
    stop("finder must be a BebelFileFinder or root path", call. = FALSE)
  }
  raw <- finder$search(
    as.character(query)[[1L]],
    as.character(current_file %||% "")[[1L]],
    as.numeric(max_threads),
    as.numeric(offset),
    as.numeric(limit),
    as.numeric(combo_boost_score_multiplier),
    as.numeric(min_combo_count),
    as.numeric(wait_timeout_ms)
  )
  n <- length(raw$path)
  out <- data.frame(
    path = raw$path,
    absolute_path = raw$absolute_path,
    file_name = raw$file_name,
    git_status = raw$git_status,
    size = raw$size,
    modified = as.POSIXct(raw$modified, origin = "1970-01-01", tz = "UTC"),
    score = raw$score,
    base_score = raw$base_score,
    match_type = raw$match_type,
    exact_match = raw$exact_match,
    is_binary = raw$is_binary,
    stringsAsFactors = FALSE
  )
  attr(out, "query") <- raw$query
  attr(out, "total_matched") <- raw$total_matched
  attr(out, "total_files") <- raw$total_files
  attr(out, "offset") <- as.integer(offset)
  attr(out, "limit") <- as.integer(limit)
  class(out) <- c("bebelFileSearchResult", class(out))
  out
}

#' @export
print.BebelFileFinder <- function(x, ...) {
  info <- x$info()
  cat("<BebelFileFinder> ", info$base_path %||% "<native-unavailable>", "\n", sep = "")
  cat("  engine: ", info$engine %||% "fff-search/fff-c", "\n", sep = "")
  invisible(x)
}

#' @export
print.bebelFileSearchResult <- function(x, ...) {
  cat("<bebelFileSearchResult> ", nrow(x), " rows", sep = "")
  total <- attr(x, "total_matched", exact = TRUE)
  if (!is.null(total)) cat(" / ", total, " matched", sep = "")
  cat("\n")
  print(utils::head(as.data.frame(x), 20L), row.names = FALSE)
  invisible(x)
}
