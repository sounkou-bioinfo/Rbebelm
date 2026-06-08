#' Define an agent-loop command
#'
#' Commands are UI-independent loop actions. A TUI or console can render the
#' command catalog, but execution happens against the `bebelAgentLoop`.
#'
#' @param name Command name without a leading slash.
#' @param fun Function called as `fun(args, loop, context)`.
#' @param description Optional human-readable description.
#' @param usage Optional usage string.
#' @return A `bebelLoopCommand` object.
#' @export
bebel_loop_command <- function(name, fun, description = NULL, usage = NULL) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("command name must be a non-empty string", call. = FALSE)
  }
  if (startsWith(name, "/")) name <- substr(name, 2L, nchar(name))
  if (!is.function(fun)) stop("fun must be a function", call. = FALSE)
  structure(
    list(name = name, fun = fun, description = description %||% name, usage = usage %||% paste0("/", name)),
    class = "bebelLoopCommand"
  )
}

#' @export
print.bebelLoopCommand <- function(x, ...) {
  cat("<bebelLoopCommand> /", x$name, "\n", sep = "")
  if (!is.null(x$description)) cat("  ", x$description, "\n", sep = "")
  invisible(x)
}

bebel_normalize_commands <- function(commands) {
  if (is.null(commands)) return(list())
  if (inherits(commands, "bebelLoopCommand")) commands <- list(commands)
  if (!is.list(commands)) stop("commands must be a list", call. = FALSE)
  out <- list()
  for (i in seq_along(commands)) {
    command <- commands[[i]]
    if (inherits(command, "bebelLoopCommand")) {
      out[[command$name]] <- command
    } else if (is.function(command)) {
      nm <- names(commands)[i]
      if (is.null(nm) || !nzchar(nm)) stop("function commands must be named", call. = FALSE)
      out[[nm]] <- bebel_loop_command(nm, command)
    } else {
      stop("commands must contain bebelLoopCommand objects or named functions", call. = FALSE)
    }
  }
  out
}

bebel_validate_hook_list <- function(hooks, what = "hooks") {
  if (is.null(hooks)) return(list())
  if (!is.list(hooks)) stop(what, " must be a named list", call. = FALSE)
  nms <- names(hooks)
  if (length(hooks) && (is.null(nms) || any(!nzchar(nms)))) {
    stop(what, " must be a named list", call. = FALSE)
  }
  bad <- !vapply(hooks, is.function, logical(1))
  if (any(bad)) stop(what, " entries must be functions", call. = FALSE)
  hooks
}

#' Define an agent-loop extension
#'
#' Extensions contribute tools, commands, hooks, and optional UI metadata to the
#' agent loop. They are registered into [bebel_agent_loop()] and are deliberately
#' UI-independent: a future Rust TUI can consume the same command/metadata catalog
#' without owning business logic.
#'
#' @param name Extension name.
#' @param tools Optional list of `bebel_tool()` objects or named functions.
#' @param commands Optional list of [bebel_loop_command()] objects or named functions.
#' @param hooks Optional named hook list.
#' @param skill_providers Optional named list of objects implementing `BebelSkillProvider`.
#' @param prompt_template_providers Optional named list of objects implementing
#'   `BebelPromptTemplateProvider`.
#' @param keybindings Optional metadata for TUI consumers.
#' @param widgets Optional metadata for TUI consumers.
#' @param metadata Optional extension metadata.
#' @return A `bebelExtension` object.
#' @export
bebel_extension <- function(
  name,
  tools = list(),
  commands = list(),
  hooks = list(),
  skill_providers = list(),
  prompt_template_providers = list(),
  keybindings = list(),
  widgets = list(),
  metadata = list()
) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("extension name must be a non-empty string", call. = FALSE)
  }
  structure(
    list(
      name = name,
      tools = normalize_bebel_tools(tools),
      commands = bebel_normalize_commands(commands),
      hooks = bebel_validate_hook_list(hooks),
      skill_providers = bebel_validate_provider_list(skill_providers, BebelSkillProvider, what = "skill_providers"),
      prompt_template_providers = bebel_validate_provider_list(prompt_template_providers, BebelPromptTemplateProvider, what = "prompt_template_providers"),
      keybindings = keybindings,
      widgets = widgets,
      metadata = metadata
    ),
    class = "bebelExtension"
  )
}

#' @export
print.bebelExtension <- function(x, ...) {
  cat("<bebelExtension> ", x$name, "\n", sep = "")
  cat("  tools: ", paste(names(x$tools), collapse = ", "), "\n", sep = "")
  cat("  commands: ", paste(paste0("/", names(x$commands)), collapse = ", "), "\n", sep = "")
  invisible(x)
}

bebel_validate_provider_list <- function(providers, interface, what = "providers") {
  if (is.null(providers)) return(list())
  if (!is.list(providers) || inherits(providers, "bebelSkillProvider") || inherits(providers, "bebelPromptTemplateProvider")) providers <- list(providers)
  out <- list()
  for (i in seq_along(providers)) {
    provider <- providers[[i]]
    bebel_assert_implements(provider, interface, arg = what)
    nm <- names(providers)[i]
    if (is.null(nm) || !nzchar(nm)) nm <- provider$name %||% paste0(what, i)
    out[[nm]] <- provider
  }
  out
}

bebel_normalize_extensions <- function(extensions) {
  if (is.null(extensions)) return(list())
  if (inherits(extensions, "bebelExtension")) extensions <- list(extensions)
  if (!is.list(extensions)) stop("extensions must be a list", call. = FALSE)
  out <- list()
  for (i in seq_along(extensions)) {
    ext <- extensions[[i]]
    bebel_assert_implements(ext, BebelAgentExtension, arg = "extensions")
    manifest <- bebel_extension_manifest(ext)
    out[[manifest$name]] <- ext
  }
  out
}

bebel_merge_named_lists <- function(lists, what = "entries") {
  out <- list()
  for (lst in lists) {
    if (!length(lst)) next
    for (nm in names(lst)) {
      if (nm %in% names(out)) stop("duplicate ", what, " name: ", nm, call. = FALSE)
      out[[nm]] <- lst[[nm]]
    }
  }
  out
}

bebel_extension_collect_tools <- function(extensions) {
  bebel_merge_named_lists(lapply(extensions, bebel_extension_tools), what = "tool")
}

bebel_extension_collect_commands <- function(extensions) {
  bebel_merge_named_lists(lapply(extensions, bebel_extension_commands), what = "command")
}

bebel_extension_collect_skill_providers <- function(extensions) {
  bebel_merge_named_lists(lapply(extensions, bebel_extension_skill_providers), what = "skill provider")
}

bebel_extension_collect_prompt_template_providers <- function(extensions) {
  bebel_merge_named_lists(lapply(extensions, bebel_extension_prompt_template_providers), what = "prompt-template provider")
}

bebel_extension_collect_hooks <- function(extensions) {
  hooks <- list()
  for (ext in extensions) {
    ext_hooks <- bebel_extension_hooks(ext)
    for (nm in names(ext_hooks)) {
      hooks[[nm]] <- c(hooks[[nm]], list(ext_hooks[[nm]]))
    }
  }
  hooks
}

bebel_hooks_to_multi <- function(hooks) {
  hooks <- bebel_validate_hook_list(hooks)
  out <- list()
  for (nm in names(hooks)) out[[nm]] <- list(hooks[[nm]])
  out
}

bebel_combine_hook_lists <- function(user_hooks = list(), contributed_hooks = list()) {
  multi <- bebel_hooks_to_multi(user_hooks)
  for (nm in names(contributed_hooks)) {
    multi[[nm]] <- c(multi[[nm]], contributed_hooks[[nm]])
  }
  out <- list()
  for (nm in names(multi)) {
    listeners <- multi[[nm]]
    out[[nm]] <- function(...) {
      value <- NULL
      for (listener in listeners) value <- listener(...)
      value
    }
  }
  out
}

bebel_collect_before_tool_call_hooks <- function(user_hooks = list(), contributed_hooks = list()) {
  out <- list()
  if (!is.null(user_hooks$before_tool_call)) out <- c(out, list(user_hooks$before_tool_call))
  if (!is.null(contributed_hooks$before_tool_call)) out <- c(out, contributed_hooks$before_tool_call)
  out
}

#' Return a loop's extension manifests
#'
#' @param loop A `bebelAgentLoop`.
#' @return A list of extension manifests.
#' @export
bebel_loop_extensions <- function(loop) {
  bebel_loop_check(loop)
  lapply(loop$extensions, bebel_extension_manifest)
}

bebel_parse_loop_command <- function(text) {
  text <- as.character(text)
  if (!length(text) || !startsWith(text[[1L]], "/")) return(NULL)
  text <- text[[1L]]
  if (startsWith(text, "//")) return(NULL)
  body <- substring(text, 2L)
  if (!nzchar(body)) return(NULL)
  parts <- strsplit(body, "\\s+", perl = TRUE)[[1]]
  name <- parts[[1L]]
  args <- trimws(sub(paste0("^", gsub("([\\W])", "\\\\\\1", name), "\\s*"), "", body, perl = TRUE))
  list(name = name, args = args, raw = text)
}

#' Return a loop's command catalog
#'
#' @param loop A `bebelAgentLoop`.
#' @return A data frame of commands.
#' @export
bebel_loop_command_catalog <- function(loop) {
  bebel_loop_check(loop)
  if (!length(loop$commands)) {
    return(data.frame(name = character(), description = character(), usage = character(), stringsAsFactors = FALSE))
  }
  data.frame(
    name = names(loop$commands),
    description = vapply(loop$commands, function(x) x$description %||% "", character(1)),
    usage = vapply(loop$commands, function(x) x$usage %||% paste0("/", x$name), character(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

#' Execute a loop command
#'
#' @param loop A `bebelAgentLoop`.
#' @param text Command text such as `"/help"`.
#' @return `TRUE` if a command was handled, otherwise `FALSE`.
#' @export
bebel_loop_execute_command <- function(loop, text) {
  bebel_loop_check(loop)
  parsed <- bebel_parse_loop_command(text)
  if (is.null(parsed)) return(FALSE)
  command <- loop$commands[[parsed$name]]
  if (is.null(command)) return(FALSE)
  bebel_loop_emit(loop, "command_start", command = parsed$name, args = parsed$args, raw = parsed$raw)
  result <- tryCatch(
    command$fun(parsed$args, loop, loop$context),
    error = function(e) e
  )
  if (inherits(result, "error")) {
    bebel_loop_emit(loop, "command_error", command = parsed$name, error = result, message = conditionMessage(result))
    stop(result)
  }
  bebel_loop_emit(loop, "command_end", command = parsed$name, result = result)
  TRUE
}
