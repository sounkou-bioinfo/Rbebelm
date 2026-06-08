#' Agent session storage directory
#'
#' Returns the directory used for backend-agnostic agent session JSONL files.
#' By default sessions are stored under
#' `tools::R_user_dir("Rbebelm", "data")/sessions/<encoded-cwd>/`, inspired by
#' Pi's per-working-directory session layout. Set `RBEBELM_SESSION_DIR` or pass
#' `session_dir` to the creation/opening helpers to override it.
#'
#' @param cwd Working directory represented by the session directory.
#' @param session_root Optional root directory. Defaults to
#'   `Sys.getenv("RBEBELM_SESSION_DIR")` or the package user data directory.
#' @param create Create the directory if needed?
#' @return A session directory path.
#' @export
agent_session_dir <- function(cwd = getwd(), session_root = NULL, create = TRUE) {
  root <- session_root %||% Sys.getenv("RBEBELM_SESSION_DIR", unset = NA_character_)
  if (is.na(root) || !nzchar(root)) {
    root <- file.path(tools::R_user_dir("Rbebelm", "data"), "sessions")
  }
  cwd <- normalizePath(cwd, winslash = "/", mustWork = FALSE)
  safe <- paste0("--", gsub("^/|[/\\\\:]", "-", cwd, perl = TRUE), "--")
  dir <- file.path(root, safe)
  if (isTRUE(create)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir
}

agent_session_timestamp <- function(time = Sys.time()) {
  format(as.POSIXct(time, tz = "UTC"), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
}

agent_session_file_timestamp <- function(time = Sys.time()) {
  gsub("[:.]", "-", agent_session_timestamp(time), perl = TRUE)
}

agent_session_random_hex <- function(n = 8L) {
  paste(sample(c(0:9, letters[1:6]), n, replace = TRUE), collapse = "")
}

agent_session_id <- function() {
  paste0(agent_session_random_hex(8L), "-", agent_session_random_hex(4L), "-", agent_session_random_hex(4L), "-", agent_session_random_hex(4L), "-", agent_session_random_hex(12L))
}

agent_session_entry_id <- function(session) {
  for (i in seq_len(100L)) {
    id <- agent_session_random_hex(8L)
    if (is.null(session$by_id[[id]])) return(id)
  }
  agent_session_id()
}

agent_session_to_json <- function(x) {
  yyjsonr::write_json_str(x, opts = bebel_json_write_opts(auto_unbox = TRUE))
}

agent_session_from_json <- function(x) {
  yyjsonr::read_json_str(x, opts = bebel_json_read_opts())
}

agent_session_write_line <- function(path, entry, append = TRUE) {
  cat(agent_session_to_json(entry), "\n", file = path, append = append, sep = "")
  invisible(path)
}

agent_session_load_entries <- function(path) {
  if (!file.exists(path)) return(list())
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  out <- list()
  for (line in lines) {
    if (!nzchar(trimws(line))) next
    entry <- tryCatch(agent_session_from_json(line), error = function(e) NULL)
    if (!is.null(entry) && is.list(entry)) out[[length(out) + 1L]] <- entry
  }
  out
}

agent_session_index <- function(session) {
  session$by_id <- new.env(parent = emptyenv())
  session$leaf_id <- NULL
  session$labels <- new.env(parent = emptyenv())
  for (entry in session$file_entries) {
    if (identical(entry$type, "session")) next
    session$by_id[[entry$id]] <- entry
    session$leaf_id <- entry$id
    if (identical(entry$type, "label")) {
      if (!is.null(entry$label) && nzchar(entry$label)) {
        session$labels[[entry$targetId]] <- entry$label
      } else if (exists(entry$targetId, envir = session$labels, inherits = FALSE)) {
        rm(list = entry$targetId, envir = session$labels)
      }
    }
  }
  invisible(session)
}

agent_session_new_env <- function(cwd, session_dir, session_file, persist = TRUE) {
  session <- new.env(parent = emptyenv())
  session$cwd <- normalizePath(cwd, winslash = "/", mustWork = FALSE)
  session$session_dir <- session_dir
  session$session_file <- session_file
  session$persist <- isTRUE(persist)
  session$file_entries <- list()
  session$by_id <- new.env(parent = emptyenv())
  session$labels <- new.env(parent = emptyenv())
  session$leaf_id <- NULL
  class(session) <- c("agentSession", "environment")
  session
}

#' Create an agent session JSONL store
#'
#' The store is backend-agnostic. It records framework/session information and
#' message-shaped data; it does not assume a BebeLM transcript implementation.
#'
#' @param cwd Working directory stored in the session header.
#' @param session_dir Optional concrete directory for the JSONL file. If `NULL`,
#'   `agent_session_dir()` is used.
#' @param id Optional session id.
#' @param parent_session Optional parent session file path for forks/clones.
#' @param name Optional display name stored as a `session_info` entry.
#' @param persist If `FALSE`, keep the session in memory only.
#' @return An `agentSession` object.
#' @export
agent_session_create <- function(
  cwd = getwd(),
  session_dir = NULL,
  id = NULL,
  parent_session = NULL,
  name = NULL,
  persist = TRUE
) {
  cwd <- normalizePath(cwd, winslash = "/", mustWork = FALSE)
  id <- id %||% agent_session_id()
  timestamp <- agent_session_timestamp()
  dir <- session_dir %||% agent_session_dir(cwd)
  if (isTRUE(persist)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  file <- if (isTRUE(persist)) file.path(dir, paste0(agent_session_file_timestamp(), "_", id, ".jsonl")) else NULL
  session <- agent_session_new_env(cwd, dir, file, persist = persist)
  header <- list(type = "session", version = 3L, id = id, timestamp = timestamp, cwd = cwd)
  if (!is.null(parent_session)) header$parentSession <- normalizePath(parent_session, winslash = "/", mustWork = FALSE)
  session$file_entries <- list(header)
  if (isTRUE(persist)) agent_session_write_line(file, header, append = FALSE)
  if (!is.null(name)) agent_session_append_session_info(session, name)
  session
}

#' Open an agent session JSONL file
#'
#' @param path Session JSONL file.
#' @param session_dir Optional session directory for future derived sessions.
#' @param cwd Optional working-directory override.
#' @return An `agentSession` object.
#' @export
agent_session_open <- function(path, session_dir = NULL, cwd = NULL) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  entries <- agent_session_load_entries(path)
  if (!length(entries) || !identical(entries[[1L]]$type, "session")) {
    stop("session file has no valid session header", call. = FALSE)
  }
  header <- entries[[1L]]
  cwd <- cwd %||% header$cwd %||% getwd()
  dir <- session_dir %||% dirname(path)
  session <- agent_session_new_env(cwd, dir, path, persist = TRUE)
  session$file_entries <- entries
  agent_session_index(session)
  session
}

agent_session_check <- function(session) {
  if (!inherits(session, "agentSession")) stop("session must be an agentSession", call. = FALSE)
  invisible(session)
}

#' Inspect agent session metadata
#'
#' @param session An `agentSession`.
#' @param id Entry id for `agent_session_get_entry()`.
#' @export
agent_session_header <- function(session) {
  agent_session_check(session)
  session$file_entries[[1L]]
}

#' @rdname agent_session_header
#' @export
agent_session_entries <- function(session) {
  agent_session_check(session)
  Filter(function(x) !identical(x$type, "session"), session$file_entries)
}

#' @rdname agent_session_header
#' @export
agent_session_leaf_id <- function(session) {
  agent_session_check(session)
  session$leaf_id
}

#' @rdname agent_session_header
#' @export
agent_session_file <- function(session) {
  agent_session_check(session)
  session$session_file
}

#' @rdname agent_session_header
#' @export
agent_session_get_entry <- function(session, id) {
  agent_session_check(session)
  if (is.null(id)) return(NULL)
  session$by_id[[id]]
}

agent_session_append_entry <- function(session, type, fields = list(), parent_id = session$leaf_id) {
  agent_session_check(session)
  if (!is.list(fields)) stop("fields must be a list", call. = FALSE)
  entry <- c(list(type = type, id = agent_session_entry_id(session), parentId = parent_id, timestamp = agent_session_timestamp()), fields)
  session$file_entries[[length(session$file_entries) + 1L]] <- entry
  session$by_id[[entry$id]] <- entry
  session$leaf_id <- entry$id
  if (identical(type, "label")) {
    if (!is.null(entry$label) && nzchar(entry$label)) {
      session$labels[[entry$targetId]] <- entry$label
    } else if (exists(entry$targetId, envir = session$labels, inherits = FALSE)) {
      rm(list = entry$targetId, envir = session$labels)
    }
  }
  if (isTRUE(session$persist) && !is.null(session$session_file)) agent_session_write_line(session$session_file, entry, append = TRUE)
  entry$id
}

#' Append a message entry to an agent session
#'
#' @param session An `agentSession`.
#' @param role Message role, e.g. `"user"`, `"assistant"`, or `"toolResult"`.
#' @param content Message content. Strings or lists of content blocks are accepted.
#' @param message Optional complete message object. If supplied, `role`, `content`,
#'   and `...` are ignored.
#' @param ... Extra message fields such as `provider`, `model`, `usage`,
#'   `stopReason`, `toolName`, or `details`.
#' @return The appended entry id.
#' @export
agent_session_append_message <- function(session, role, content, message = NULL, ...) {
  fields <- list(...)
  if (is.null(message)) message <- c(list(role = role, content = content), fields)
  agent_session_append_entry(session, "message", list(message = message))
}

#' Append session metadata and extension entries
#'
#' @param session An `agentSession`.
#' @param name Session display name.
#' @param custom_type Extension or custom entry type.
#' @param data Extension state data. Custom entries do not enter model context.
#' @param content Custom message content. Custom messages may enter model context.
#' @param display Should a UI render the custom message?
#' @param details Optional extension-specific metadata.
#' @return The appended entry id.
#' @export
agent_session_append_session_info <- function(session, name) {
  agent_session_append_entry(session, "session_info", list(name = trimws(as.character(name)[[1L]])))
}

#' @rdname agent_session_append_session_info
#' @export
agent_session_append_custom <- function(session, custom_type, data = NULL) {
  fields <- list(customType = as.character(custom_type)[[1L]])
  if (!is.null(data)) fields$data <- data
  agent_session_append_entry(session, "custom", fields)
}

#' @rdname agent_session_append_session_info
#' @export
agent_session_append_custom_message <- function(session, custom_type, content, display = TRUE, details = NULL) {
  fields <- list(customType = as.character(custom_type)[[1L]], content = content, display = isTRUE(display))
  if (!is.null(details)) fields$details <- details
  agent_session_append_entry(session, "custom_message", fields)
}

#' Append model/thinking/compaction/branch metadata
#'
#' @param session An `agentSession`.
#' @param provider Provider id.
#' @param model_id Model id.
#' @param thinking_level Thinking/reasoning level.
#' @param summary Summary text.
#' @param first_kept_entry_id First entry kept after compaction.
#' @param tokens_before Number of tokens before compaction.
#' @param details Optional metadata.
#' @param from_hook Was the entry created by an extension hook?
#' @param from_id Branch source entry id.
#' @return The appended entry id.
#' @export
agent_session_append_model_change <- function(session, provider, model_id) {
  agent_session_append_entry(session, "model_change", list(provider = provider, modelId = model_id))
}

#' @rdname agent_session_append_model_change
#' @export
agent_session_append_thinking_level_change <- function(session, thinking_level) {
  agent_session_append_entry(session, "thinking_level_change", list(thinkingLevel = thinking_level))
}

#' @rdname agent_session_append_model_change
#' @export
agent_session_append_compaction <- function(session, summary, first_kept_entry_id, tokens_before, details = NULL, from_hook = FALSE) {
  fields <- list(summary = summary, firstKeptEntryId = first_kept_entry_id, tokensBefore = as.integer(tokens_before), fromHook = isTRUE(from_hook))
  if (!is.null(details)) fields$details <- details
  agent_session_append_entry(session, "compaction", fields)
}

#' @rdname agent_session_append_model_change
#' @export
agent_session_append_branch_summary <- function(session, from_id, summary, details = NULL, from_hook = FALSE) {
  agent_session_checkout(session, from_id)
  fields <- list(fromId = from_id %||% "root", summary = summary, fromHook = isTRUE(from_hook))
  if (!is.null(details)) fields$details <- details
  agent_session_append_entry(session, "branch_summary", fields, parent_id = from_id)
}

#' Append or clear a label on a session entry
#'
#' @param session An `agentSession`.
#' @param target_id Entry id to label.
#' @param label Label text, or `NULL`/empty string to clear.
#' @export
agent_session_append_label <- function(session, target_id, label = NULL) {
  agent_session_check(session)
  if (is.null(agent_session_get_entry(session, target_id))) stop("target entry not found", call. = FALSE)
  agent_session_append_entry(session, "label", list(targetId = target_id, label = label %||% ""))
}

#' Move the current session leaf
#'
#' @param session An `agentSession`.
#' @param entry_id Entry id to continue from, or `NULL` to reset before the root.
#' @return The session, invisibly.
#' @export
agent_session_checkout <- function(session, entry_id = NULL) {
  agent_session_check(session)
  if (!is.null(entry_id) && is.null(agent_session_get_entry(session, entry_id))) stop("entry not found", call. = FALSE)
  session$leaf_id <- entry_id
  invisible(session)
}

#' Return the branch from root to a session entry
#'
#' @param session An `agentSession`.
#' @param from_id Entry id. Defaults to the current leaf.
#' @return A list of session entries in path order.
#' @export
agent_session_branch <- function(session, from_id = agent_session_leaf_id(session)) {
  agent_session_check(session)
  path <- list()
  current <- if (is.null(from_id)) NULL else agent_session_get_entry(session, from_id)
  while (!is.null(current)) {
    path <- c(list(current), path)
    current <- if (is.null(current$parentId)) NULL else agent_session_get_entry(session, current$parentId)
  }
  path
}

agent_session_message_from_entry <- function(entry) {
  if (identical(entry$type, "message")) return(entry$message)
  if (identical(entry$type, "custom_message")) {
    out <- list(role = "custom", customType = entry$customType, content = entry$content, display = isTRUE(entry$display))
    if (!is.null(entry$details)) out$details <- entry$details
    return(out)
  }
  if (identical(entry$type, "branch_summary")) return(list(role = "branchSummary", summary = entry$summary, fromId = entry$fromId))
  NULL
}

#' Build model context from the active session branch
#'
#' @param session An `agentSession`.
#' @return A list with `messages`, `thinking_level`, `model`, and branch `entries`.
#' @export
agent_session_context <- function(session) {
  path <- agent_session_branch(session)
  thinking_level <- "off"
  model <- NULL
  compaction_index <- NA_integer_
  for (i in seq_along(path)) {
    entry <- path[[i]]
    if (identical(entry$type, "thinking_level_change")) thinking_level <- entry$thinkingLevel
    if (identical(entry$type, "model_change")) model <- list(provider = entry$provider, modelId = entry$modelId)
    if (identical(entry$type, "message") && identical(entry$message$role, "assistant")) {
      if (!is.null(entry$message$provider) || !is.null(entry$message$model)) model <- list(provider = entry$message$provider %||% NA_character_, modelId = entry$message$model %||% NA_character_)
    }
    if (identical(entry$type, "compaction")) compaction_index <- i
  }
  messages <- list()
  append_entry <- function(entry) {
    msg <- agent_session_message_from_entry(entry)
    if (!is.null(msg)) messages[[length(messages) + 1L]] <<- msg
  }
  if (!is.na(compaction_index)) {
    comp <- path[[compaction_index]]
    messages[[length(messages) + 1L]] <- list(role = "compactionSummary", summary = comp$summary, tokensBefore = comp$tokensBefore)
    found <- FALSE
    for (i in seq_len(compaction_index - 1L)) {
      if (identical(path[[i]]$id, comp$firstKeptEntryId)) found <- TRUE
      if (isTRUE(found)) append_entry(path[[i]])
    }
    if (compaction_index < length(path)) for (i in seq.int(compaction_index + 1L, length(path))) append_entry(path[[i]])
  } else {
    for (entry in path) append_entry(entry)
  }
  list(messages = messages, thinking_level = thinking_level, model = model, entries = path)
}

#' Return an agent session tree
#'
#' @param session An `agentSession`.
#' @return A nested list of tree nodes with `entry`, `children`, and optional `label`.
#' @export
agent_session_tree <- function(session) {
  agent_session_check(session)
  entries <- agent_session_entries(session)
  by_parent <- list()
  key <- function(x) if (is.null(x)) "__root__" else x
  for (entry in entries) {
    parent_key <- key(entry$parentId)
    by_parent[[parent_key]] <- c(by_parent[[parent_key]], list(entry))
  }
  build <- function(entry) {
    children <- lapply(by_parent[[key(entry$id)]] %||% list(), build)
    label <- if (exists(entry$id, envir = session$labels, inherits = FALSE)) session$labels[[entry$id]] else NULL
    node <- list(entry = entry, children = children)
    if (!is.null(label)) node$label <- label
    node
  }
  lapply(by_parent[["__root__"]] %||% list(), build)
}

agent_session_copy_entries <- function(target, entries) {
  for (entry in entries) {
    target$file_entries[[length(target$file_entries) + 1L]] <- entry
    target$by_id[[entry$id]] <- entry
    target$leaf_id <- entry$id
    if (isTRUE(target$persist)) agent_session_write_line(target$session_file, entry, append = TRUE)
  }
  agent_session_index(target)
  target
}

#' Fork an agent session file into a new session file
#'
#' `agent_session_fork()` copies all non-header entries from an existing JSONL
#' file. `agent_session_clone_branch()` copies only the path from the root to a
#' selected leaf, matching Pi's active-branch clone behavior.
#'
#' @param source_path Source JSONL session file.
#' @param cwd Target working directory for the new session.
#' @param session_dir Optional concrete target session directory.
#' @param id Optional new session id.
#' @param session Source `agentSession` for branch cloning.
#' @param leaf_id Leaf entry id to clone. Defaults to the source session leaf.
#' @return The opened forked/cloned `agentSession`.
#' @export
agent_session_fork <- function(source_path, cwd = getwd(), session_dir = NULL, id = NULL) {
  source_path <- normalizePath(source_path, winslash = "/", mustWork = FALSE)
  source <- agent_session_open(source_path)
  target <- agent_session_create(cwd = cwd, session_dir = session_dir, id = id, parent_session = source_path)
  agent_session_copy_entries(target, agent_session_entries(source))
}

#' @rdname agent_session_fork
#' @export
agent_session_clone_branch <- function(session, leaf_id = agent_session_leaf_id(session), cwd = session$cwd, session_dir = session$session_dir, id = NULL) {
  agent_session_check(session)
  parent <- agent_session_file(session)
  target <- agent_session_create(cwd = cwd, session_dir = session_dir, id = id, parent_session = parent)
  path <- agent_session_branch(session, leaf_id)
  agent_session_copy_entries(target, path)
}

#' List agent session files
#'
#' @param cwd Working directory used for default session directory lookup.
#' @param session_dir Optional concrete directory to scan.
#' @return A data frame with basic session metadata.
#' @export
agent_session_list <- function(cwd = getwd(), session_dir = NULL) {
  dir <- session_dir %||% agent_session_dir(cwd, create = FALSE)
  if (!dir.exists(dir)) {
    return(data.frame(path = character(), id = character(), cwd = character(), name = character(), created = as.POSIXct(character()), modified = as.POSIXct(character()), entries = integer(), stringsAsFactors = FALSE))
  }
  files <- list.files(dir, pattern = "[.]jsonl$", full.names = TRUE)
  rows <- lapply(files, function(path) {
    entries <- agent_session_load_entries(path)
    if (!length(entries) || !identical(entries[[1L]]$type, "session")) return(NULL)
    header <- entries[[1L]]
    name <- NA_character_
    first <- NA_character_
    for (entry in entries[-1L]) {
      if (identical(entry$type, "session_info")) name <- entry$name %||% NA_character_
      if (is.na(first) && identical(entry$type, "message") && identical(entry$message$role, "user")) first <- as.character(entry$message$content)[[1L]]
    }
    info <- file.info(path)
    data.frame(path = path, id = header$id, cwd = header$cwd %||% NA_character_, name = name, created = as.POSIXct(header$timestamp, tz = "UTC"), modified = info$mtime, entries = max(length(entries) - 1L, 0L), first_message = first, stringsAsFactors = FALSE)
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) return(data.frame(path = character(), id = character(), cwd = character(), name = character(), created = as.POSIXct(character()), modified = as.POSIXct(character()), entries = integer(), first_message = character(), stringsAsFactors = FALSE))
  out <- do.call(rbind, rows)
  out[order(out$modified, decreasing = TRUE), , drop = FALSE]
}

#' @export
print.agentSession <- function(x, ...) {
  header <- agent_session_header(x)
  cat("<agentSession> ", header$id, "\n", sep = "")
  cat("  file: ", agent_session_file(x) %||% "<memory>", "\n", sep = "")
  cat("  entries: ", length(agent_session_entries(x)), "\n", sep = "")
  cat("  leaf: ", agent_session_leaf_id(x) %||% "<root>", "\n", sep = "")
  invisible(x)
}
