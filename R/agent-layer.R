# R-native agent layer ---------------------------------------------------------

bebel_agent_layer_stopif <- function(x, msg) {
  if (!isTRUE(x)) stop(msg, call. = FALSE)
}

bebel_agent_format_value <- function(x, max_chars = 4000L) {
  if (is.character(x) && length(x) == 1L) {
    out <- x
  } else {
    out <- paste(utils::capture.output(print(x)), collapse = "\n")
  }
  if (!is.na(max_chars) && nchar(out, type = "chars") > max_chars) {
    paste0(substr(out, 1L, max_chars), "\n[truncated]")
  } else {
    out
  }
}

bebel_agent_tool_text <- function(result) {
  if (is.list(result) && !is.null(result$text)) result$text else bebel_agent_format_value(result)
}

bebel_namespace_available <- function(pkg) {
  isTRUE(do.call("requireNamespace", list(as.character(pkg)[[1L]], quietly = TRUE)))
}

bebel_console_command <- function(name, fun, description = "", usage = NULL, aliases = character()) {
  structure(
    list(
      name = name,
      fun = fun,
      description = description,
      usage = usage %||% paste0("/", name),
      aliases = aliases
    ),
    class = "bebelConsoleCommand"
  )
}

bebel_console_parse_command <- function(text) {
  text <- trimws(as.character(text)[[1L]])
  if (!startsWith(text, "/") || startsWith(text, "//")) return(NULL)
  body <- trimws(sub("^/", "", text))
  if (!nzchar(body)) return(NULL)
  name <- tolower(strsplit(body, "\\s+", perl = TRUE)[[1L]][[1L]])
  args <- if (grepl("\\s", body, perl = TRUE)) trimws(sub("^[^[:space:]]+\\s*", "", body, perl = TRUE)) else ""
  list(name = name, args = args, raw = text)
}

bebel_console_command_catalog <- function(commands) {
  data.frame(
    name = names(commands),
    usage = vapply(commands, `[[`, character(1), "usage"),
    description = vapply(commands, `[[`, character(1), "description"),
    aliases = vapply(commands, function(x) paste(x$aliases %||% character(), collapse = ", "), character(1)),
    stringsAsFactors = FALSE
  )
}

bebel_console_command_aliases <- function(commands) {
  aliases <- unlist(lapply(names(commands), function(name) {
    stats::setNames(rep(name, length(commands[[name]]$aliases %||% character())), commands[[name]]$aliases %||% character())
  }), use.names = TRUE)
  c(stats::setNames(names(commands), names(commands)), aliases)
}

bebel_console_dispatch_command <- function(text, commands, session, input_con = NULL) {
  parsed <- bebel_console_parse_command(text)
  if (is.null(parsed)) return(list(handled = FALSE, quit = FALSE))
  aliases <- bebel_console_command_aliases(commands)
  target <- unname(aliases[parsed$name])
  if (!length(target) || is.na(target)) target <- parsed$name
  command <- commands[[target]]
  if (is.null(command)) return(list(handled = FALSE, quit = FALSE, name = parsed$name))
  result <- tryCatch(
    command$fun(parsed$args, session = session, input_con = input_con, commands = commands, parsed = parsed),
    error = function(e) {
      message("Command error: ", conditionMessage(e))
      list()
    }
  )
  if (isTRUE(result)) result <- list(quit = TRUE)
  if (is.null(result) || !is.list(result)) result <- list()
  quit <- isTRUE(result$quit)
  result$quit <- NULL
  c(list(handled = TRUE, quit = quit, name = target), result)
}

bebel_graphics_device <- function(device = NULL, interactive_default = TRUE) {
  device <- device %||%
    getOption("Rbebelm.graphics.device", NULL) %||%
    Sys.getenv("RBEBELM_GRAPHICS_DEVICE", unset = NULL) %||%
    "auto"
  device <- tolower(as.character(device)[[1L]])
  if (!nzchar(device)) device <- "auto"
  if (identical(device, "auto")) {
    socket <- Sys.getenv("JGD_SOCKET", unset = "")
    if (nzchar(socket) && bebel_namespace_available("jgd")) return("jgd")
    if (isTRUE(interactive_default) && interactive()) return("native")
    return("png")
  }
  aliases <- c(ascii = "devout-ascii", devout = "devout-ascii", devout_ascii = "devout-ascii")
  if (device %in% names(aliases)) device <- aliases[[device]]
  match.arg(device, c("native", "png", "jgd", "devout-ascii"))
}

bebel_plot_result <- function(text, device, path = NULL, mime = NULL, socket = NULL, width = NULL, height = NULL) {
  structure(
    list(text = text, device = device, path = path, mime = mime, socket = socket, width = width, height = height),
    class = "bebelPlotResult"
  )
}

bebel_graphics_open_jgd <- function(width, height, socket) {
  jgd <- getExportedValue("jgd", "jgd")
  jgd(width = as.numeric(width) / 96, height = as.numeric(height) / 96, dpi = 96, socket = socket)
}

bebel_graphics_render_devout_ascii <- function(exprs, envir, width, height) {
  if (!bebel_namespace_available("devout")) {
    stop("devout-ascii graphics requested but package 'devout' is not installed", call. = FALSE)
  }
  ascii <- getExportedValue("devout", "ascii")
  cols <- max(30L, min(160L, as.integer(width / 8L)))
  rows <- max(12L, min(80L, as.integer(height / 16L)))
  path <- tempfile("rbebelm-devout-ascii-", fileext = ".txt")
  opened <- FALSE
  ascii(filename = path, width = cols, height = rows)
  opened <- TRUE
  on.exit({
    if (opened) grDevices::dev.off()
  }, add = TRUE)
  for (expr in exprs) eval(expr, envir = envir)
  grDevices::dev.off()
  opened <- FALSE
  txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
  bebel_plot_result(
    paste(c(sprintf("Plot rendered via devout::ascii (%dx%d characters):", cols, rows), txt), collapse = "\n"),
    device = "devout-ascii",
    mime = "text/plain",
    width = cols,
    height = rows
  )
}

bebel_graphics_render_plot <- function(exprs, envir, cwd = getwd(), width = 800L, height = 600L, device = NULL) {
  width <- suppressWarnings(as.integer(width %||% 800L))
  height <- suppressWarnings(as.integer(height %||% 600L))
  width <- if (length(width) && !is.na(width) && width >= 100L) width[[1L]] else 800L
  height <- if (length(height) && !is.na(height) && height >= 100L) height[[1L]] else 600L
  device <- bebel_graphics_device(device)
  if (identical(device, "native")) {
    for (expr in exprs) eval(expr, envir = envir)
    return(bebel_plot_result("Plot displayed on the native R graphics device.", device = "native", width = width, height = height))
  }
  if (identical(device, "devout-ascii")) {
    out <- tryCatch(bebel_graphics_render_devout_ascii(exprs, envir, width, height), error = function(e) e)
    if (!inherits(out, "error")) return(out)
    warning("devout-ascii graphics failed; falling back to PNG: ", conditionMessage(out), call. = FALSE)
  }
  if (identical(device, "jgd")) {
    socket <- Sys.getenv("JGD_SOCKET", unset = "")
    if (nzchar(socket) && bebel_namespace_available("jgd")) {
      opened <- FALSE
      out <- tryCatch({
        bebel_graphics_open_jgd(width, height, socket)
        opened <- TRUE
        on.exit({
          if (opened) grDevices::dev.off()
        }, add = TRUE)
        for (expr in exprs) eval(expr, envir = envir)
        grDevices::dev.off()
        opened <- FALSE
        bebel_plot_result(paste("Plot streamed via jgd to:", socket), device = "jgd", socket = socket, width = width, height = height)
      }, error = function(e) e)
      if (!inherits(out, "error")) return(out)
      warning("jgd graphics failed; falling back to PNG: ", conditionMessage(out), call. = FALSE)
    } else {
      warning("jgd graphics requested but jgd/JGD_SOCKET is unavailable; falling back to PNG", call. = FALSE)
    }
  }
  path <- bebel_console_save_plot(exprs, envir, cwd = cwd, width = width, height = height)
  bebel_plot_result(paste("Plot saved to:", path), device = "png", path = path, mime = "image/png", width = width, height = height)
}

bebel_agent_require <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Package '", pkg, "' is required for this optional feature.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Create an Rbebelm agent tool specification
#'
#' This is a small metadata layer on top of [bebel_tool()]. It keeps a
#' JSON-schema-like parameter specification next to the executable R function so
#' the same tool catalog can be used by the console agent and the RPC surface.
#'
#' @param name Tool name.
#' @param description Short description shown to the model and clients.
#' @param params Named list of parameter specifications. Each entry may contain
#'   `type`, `description`, `required`, and `enum`.
#' @param fun Function called as `fun(args, context, call)` or any subset of
#'   those names, following [bebel_tool()] conventions.
#' @return A `bebelAgentTool` object.
#' @export
bebel_agent_tool <- function(name, description, params = list(), fun) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("tool name must be a non-empty string", call. = FALSE)
  }
  if (!is.character(description) || length(description) != 1L) {
    stop("tool description must be a string", call. = FALSE)
  }
  if (!is.list(params)) stop("params must be a named list", call. = FALSE)
  if (!is.function(fun)) stop("fun must be a function", call. = FALSE)

  structure(
    list(
      name = name,
      description = description,
      params = params,
      tool = bebel_tool(name, fun, description = description, schema = bebel_agent_tool_schema(params))
    ),
    class = "bebelAgentTool"
  )
}

#' @export
print.bebelAgentTool <- function(x, ...) {
  cat("<bebelAgentTool> ", x$name, "\n", sep = "")
  cat("  ", x$description, "\n", sep = "")
  invisible(x)
}

bebel_agent_tool_schema <- function(params = list()) {
  required <- names(params)[vapply(params, function(x) isTRUE(x$required), logical(1))]
  properties <- lapply(params, function(x) {
    x$required <- NULL
    if (is.null(x$type)) x$type <- "string"
    x
  })
  if (length(properties) == 0L) properties <- stats::setNames(list(), character())
  list(
    type = "object",
    properties = properties,
    required = as.list(required)
  )
}

bebel_agent_normalize_tools <- function(tools) {
  if (is.null(tools)) return(list())
  if (inherits(tools, "bebelAgentTool")) tools <- list(tools)
  if (!is.list(tools)) stop("tools must be a list", call. = FALSE)
  out <- list()
  for (i in seq_along(tools)) {
    tool <- tools[[i]]
    if (inherits(tool, "bebelAgentTool")) {
      out[[tool$name]] <- tool
    } else if (inherits(tool, "bebelTool")) {
      out[[tool$name]] <- bebel_agent_tool(
        tool$name,
        tool$description %||% tool$name,
        params = list(),
        fun = tool$fun
      )
    } else if (is.function(tool)) {
      nm <- names(tools)[i]
      if (is.null(nm) || !nzchar(nm)) stop("function tools must be named", call. = FALSE)
      out[[nm]] <- bebel_agent_tool(nm, nm, params = list(), fun = tool)
    } else {
      stop("tools must contain bebelAgentTool, bebelTool, or function objects", call. = FALSE)
    }
  }
  out
}

bebel_agent_as_bebel_tools <- function(tools) {
  lapply(bebel_agent_normalize_tools(tools), `[[`, "tool")
}

#' Describe an Rbebelm agent tool catalog
#'
#' @param tools A tool list accepted by [bebel_r_agent()].
#' @return A data frame with tool names and descriptions.
#' @export
bebel_agent_tool_catalog <- function(tools) {
  tools <- bebel_agent_normalize_tools(tools)
  data.frame(
    name = names(tools),
    description = vapply(tools, function(x) x$description, character(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

bebel_agent_tool_signature <- function(tool) {
  params <- names(tool$params)
  if (!length(params)) return(paste0(tool$name, "()"))
  params <- vapply(params, function(nm) {
    if (isTRUE(tool$params[[nm]]$required)) nm else paste0(nm, "?")
  }, character(1))
  paste0(tool$name, "(", paste(params, collapse = ", "), ")")
}

bebel_agent_tools_prompt <- function(tools, detail = c("compact", "full")) {
  detail <- match.arg(detail)
  tools <- bebel_agent_normalize_tools(tools)
  if (!length(tools)) return("No tools are available.")

  if (identical(detail, "compact")) {
    signatures <- vapply(tools, bebel_agent_tool_signature, character(1))
    return(paste0(
      "Tools: ", paste(signatures, collapse = "; "), ". ",
      "If needed, call one tool only as <|tool_call_start|>[tool_name(arg=\"value\")]<|tool_call_end|>. ",
      "After a tool result, answer briefly."
    ))
  }

  parts <- vapply(tools, function(tool) {
    params <- tool$params
    if (length(params)) {
      arg_lines <- vapply(names(params), function(nm) {
        p <- params[[nm]]
        req <- if (isTRUE(p$required)) " required" else " optional"
        sprintf("  - %s (%s,%s): %s", nm, p$type %||% "string", req, p$description %||% "")
      }, character(1))
      args <- paste(arg_lines, collapse = "\n")
    } else {
      args <- "  - no documented arguments"
    }
    sprintf("%s: %s\n%s", tool$name, tool$description, args)
  }, character(1))
  paste(
    "Available tools. Call exactly one tool when needed using this BebeLM form:",
    "<|tool_call_start|>[tool_name(arg=\"value\")]<|tool_call_end|>",
    "After a tool result is returned, answer the user briefly.",
    "",
    paste(parts, collapse = "\n\n"),
    sep = "\n"
  )
}

bebel_agent_default_system <- function(tools, detail = c("compact", "full")) {
  detail <- match.arg(detail)
  tools <- bebel_agent_normalize_tools(tools)
  has_r_plot <- "r_plot" %in% names(tools)
  plot_hint <- if (has_r_plot) {
    "For simple plot requests, use r_plot directly with reasonable base R code. Built-in datasets such as mtcars are available; for example use plot(mtcars$wt, mtcars$mpg, xlab='wt', ylab='mpg'). If a tool error reports a typo, correct it and retry."
  } else {
    "If the user asks for a plot, tell them they can use the UI slash command /rplot [plot-code], or restart with --allow-eval if they want the model to call r_plot."
  }
  guidelines <- c(
    "Be concise and direct.",
    "Use the declared tools when you need R objects, files, documentation, code execution, or plots; do not pretend to have used a tool.",
    "If a tool is needed, emit only one tool call in the advertised BebeLM tool-call format, then wait for the tool result.",
    "After a tool result, answer from the observed result. If a tool errors because of a typo or missing object, correct the call when the correction is clear; otherwise explain the issue briefly.",
    "Do not claim a common R dataset or object is unavailable until you have checked or a tool result proves it.",
    plot_hint
  )
  if (identical(detail, "compact")) {
    return(paste(
      "You are an expert R-native assistant operating inside Rbebelm, an R agent/frontend framework.",
      "Available tools are declared separately by the host.",
      "Guidelines:",
      paste0("- ", guidelines, collapse = "\n"),
      sprintf("Current working directory: %s", normalizePath(getwd(), mustWork = FALSE)),
      sep = "\n"
    ))
  }

  paste(
    "You are an expert R-native assistant operating inside Rbebelm, an R agent/frontend framework.",
    "You help users inspect R state, read files, run R code when enabled, create plots, and explain results.",
    "Available tools are declared separately by the host.",
    "Guidelines:",
    paste0("- ", guidelines, collapse = "\n"),
    sprintf("Current working directory: %s", normalizePath(getwd(), mustWork = FALSE)),
    sep = "\n"
  )
}

#' Built-in R session tools for the Rbebelm agent layer
#'
#' The default catalog is intentionally small. It exposes read-only file and R
#' session inspection tools plus optional R evaluation and plot rendering. These
#' are ordinary R functions and run in the current R process. Plot rendering is
#' device-backed: `options(Rbebelm.graphics.device=)` or the
#' `RBEBELM_GRAPHICS_DEVICE` environment variable may be `"auto"`, `"native"`,
#' `"png"`, `"jgd"`, or `"devout-ascii"`.
#'
#' @param env Environment used by `r_objects`, `r_eval`, and `r_plot`.
#' @param cwd Working directory for file and plot tools.
#' @param allow_eval Whether to include the `r_eval` and `r_plot` tools. If
#'   `FALSE`, code-evaluation tools are not advertised to the model.
#' @param max_chars Maximum characters returned from a single tool.
#' @return A named list of `bebelAgentTool` objects.
#' @export
bebel_default_r_tools <- function(env = .GlobalEnv, cwd = getwd(), allow_eval = FALSE, max_chars = 4000L) {
  force(env)
  force(cwd)
  force(allow_eval)
  force(max_chars)

  resolve_path <- function(path = ".") {
    path <- path %||% "."
    if (!nzchar(trimws(path))) path <- "."
    path <- path.expand(path)
    if (!grepl("^(/|[A-Za-z]:[/\\\\])", path)) {
      path <- file.path(cwd, path)
    }
    normalizePath(path, mustWork = FALSE)
  }
  strip_root <- function(path, root) {
    prefix <- if (endsWith(root, .Platform$file.sep)) root else paste0(root, .Platform$file.sep)
    ifelse(startsWith(path, prefix), substr(path, nchar(prefix) + 1L, nchar(path)), path)
  }
  is_text_file <- function(path) {
    bytes <- tryCatch(readBin(path, what = "raw", n = 4096L), error = function(e) raw())
    !length(bytes) || !any(bytes == as.raw(0))
  }

  tools <- list(
    r_objects = bebel_agent_tool(
      "r_objects",
      "List objects in the configured R environment.",
      params = list(
        pattern = list(type = "string", description = "Optional regular expression filter.", required = FALSE)
      ),
      fun = function(args, context, call) {
        pattern <- args$pattern %||% ""
        nms <- if (!nzchar(pattern)) ls(envir = env) else ls(envir = env, pattern = pattern)
        if (!length(nms)) return("No objects found.")
        info <- vapply(nms, function(nm) {
          obj <- get(nm, envir = env)
          sprintf("%s: %s", nm, paste(class(obj), collapse = "/"))
        }, character(1))
        bebel_agent_format_value(paste(info, collapse = "\n"), max_chars)
      }
    ),
    r_eval = bebel_agent_tool(
      "r_eval",
      "Evaluate R code in the configured environment and return printed output.",
      params = list(
        code = list(type = "string", description = "R code to evaluate.", required = TRUE)
      ),
      fun = function(args, context, call) {
        if (!isTRUE(allow_eval)) {
          return("r_eval is disabled for this agent. Recreate the agent with allow_eval = TRUE to enable it.")
        }
        code <- args$code %||% ""
        expr <- parse(text = code)
        out <- utils::capture.output(value <- eval(expr, envir = env))
        if (length(out)) {
          txt <- paste(out, collapse = "\n")
        } else if (is.null(value)) {
          txt <- "NULL"
        } else {
          txt <- paste(utils::capture.output(print(value)), collapse = "\n")
        }
        bebel_agent_format_value(txt, max_chars)
      }
    ),
    r_plot = bebel_agent_tool(
      "r_plot",
      "Render R plotting code using the configured R graphics device and return the resulting artifact or device message.",
      params = list(
        code = list(type = "string", description = "R plotting code, such as plot(mpg ~ cyl, mtcars).", required = TRUE),
        width = list(type = "integer", description = "Requested plot width in pixels for file/stream devices.", required = FALSE),
        height = list(type = "integer", description = "Requested plot height in pixels for file/stream devices.", required = FALSE)
      ),
      fun = function(args, context, call) {
        if (!isTRUE(allow_eval)) {
          return("r_plot is disabled for this agent. Recreate the agent with allow_eval = TRUE to enable it, or use the UI command /rplot [plot-code].")
        }
        code <- args$code %||% ""
        expr <- tryCatch(parse(text = code), error = function(e) e)
        if (inherits(expr, "error")) return(paste("r_plot parse error:", conditionMessage(expr)))
        width <- suppressWarnings(as.integer(args$width %||% 800L))
        height <- suppressWarnings(as.integer(args$height %||% 600L))
        out <- tryCatch(
          {
            bebel_graphics_render_plot(expr, env, cwd = cwd, width = width, height = height)
          },
          error = function(e) {
            msg <- conditionMessage(e)
            hint <- ""
            if (grepl("object 'mtgcars' not found", msg, fixed = TRUE)) {
              hint <- " Did you mean the built-in dataset 'mtcars'? Try plot(mtcars$wt, mtcars$mpg, xlab='wt', ylab='mpg')."
            } else if (grepl("object .* not found", msg)) {
              hint <- " Check object names with r_objects, or use a built-in dataset such as mtcars."
            }
            paste0("r_plot error: ", msg, hint)
          }
        )
        out
      }
    ),
    r_help = bebel_agent_tool(
      "r_help",
      "Read R help for a topic, optionally in a package.",
      params = list(
        topic = list(type = "string", description = "Help topic or function name.", required = TRUE),
        package = list(type = "string", description = "Optional package name.", required = FALSE)
      ),
      fun = function(args, context, call) {
        topic <- args$topic %||% ""
        pkg <- args$package %||% NULL
        h <- tryCatch(utils::help(topic, package = pkg), error = function(e) NULL)
        if (length(h) == 0L) return(paste("No help found for", topic))
        txt <- paste(utils::capture.output(print(h)), collapse = "\n")
        bebel_agent_format_value(txt, max_chars)
      }
    ),
    list_files = bebel_agent_tool(
      "list_files",
      "Fuzzy-search files under a directory using the native FFF file finder.",
      params = list(
        query = list(type = "string", description = "Fuzzy file query. Empty returns FFF's top-ranked files.", required = FALSE),
        path = list(type = "string", description = "Directory path relative to the agent cwd.", required = FALSE),
        pattern = list(type = "string", description = "Optional R regex post-filter applied to result paths.", required = FALSE),
        limit = list(type = "integer", description = "Maximum number of entries.", required = FALSE)
      ),
      fun = function(args, context, call) {
        root <- resolve_path(args$path %||% ".")
        if (!dir.exists(root)) return(paste("Directory not found:", root))
        limit <- as.integer(args$limit %||% 100L)
        if (is.na(limit) || limit < 1L) limit <- 100L
        query <- as.character(args$query %||% "")[[1L]]
        found <- tryCatch(
          bebel_file_search(root, query = query, limit = limit),
          error = function(e) e
        )
        if (inherits(found, "error")) {
          return(paste("FFF file search unavailable:", conditionMessage(found)))
        }
        if (!nrow(found)) return(paste("No files found in", root))
        rel <- found$path
        if (!is.null(args$pattern) && nzchar(args$pattern)) rel <- rel[grepl(args$pattern, rel)]
        if (!length(rel)) return("No files matched the post-filter.")
        scores <- found$score[match(rel, found$path)]
        txt <- paste(sprintf("%s\t(score=%s)", rel, scores), collapse = "\n")
        bebel_agent_format_value(txt, max_chars)
      }
    ),
    read_file = bebel_agent_tool(
      "read_file",
      "Read a text file.",
      params = list(
        path = list(type = "string", description = "File path relative to the agent cwd.", required = TRUE),
        from = list(type = "integer", description = "First line to read, 1-based.", required = FALSE),
        lines = list(type = "integer", description = "Maximum number of lines.", required = FALSE)
      ),
      fun = function(args, context, call) {
        path <- resolve_path(args$path)
        if (!file.exists(path)) return(paste("File not found:", path))
        if (dir.exists(path)) return(paste("Path is a directory:", path))
        x <- readLines(path, warn = FALSE)
        from <- as.integer(args$from %||% 1L)
        if (is.na(from) || from < 1L) from <- 1L
        n <- args$lines
        to <- if (is.null(n)) length(x) else min(length(x), from + as.integer(n) - 1L)
        if (!length(x) || from > length(x)) return("(empty range)")
        idx <- from:to
        txt <- paste(sprintf("%d | %s", idx, x[idx]), collapse = "\n")
        bebel_agent_format_value(txt, max_chars)
      }
    ),
    grep_files = bebel_agent_tool(
      "grep_files",
      "Search text files by regex.",
      params = list(
        pattern = list(type = "string", description = "Regex pattern to search for.", required = TRUE),
        path = list(type = "string", description = "Directory path relative to cwd.", required = FALSE),
        glob = list(type = "string", description = "Optional filename regex filter.", required = FALSE),
        limit = list(type = "integer", description = "Maximum number of matching lines.", required = FALSE)
      ),
      fun = function(args, context, call) {
        root <- resolve_path(args$path %||% ".")
        if (!dir.exists(root)) return(paste("Directory not found:", root))
        files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
        files <- files[file.exists(files) & !dir.exists(files)]
        if (!is.null(args$glob)) files <- files[grepl(args$glob, basename(files))]
        limit <- as.integer(args$limit %||% 100L)
        if (is.na(limit) || limit < 1L) limit <- 100L
        hits <- character()
        for (f in files) {
          if (length(hits) >= limit) break
          if (!is_text_file(f)) next
          lines <- tryCatch(
            suppressWarnings(readLines(f, warn = FALSE)),
            error = function(e) character()
          )
          if (!length(lines)) next
          idx <- suppressWarnings(grep(args$pattern, lines, useBytes = TRUE))
          if (length(idx)) {
            rel <- strip_root(f, root)
            add <- sprintf("%s:%d: %s", rel, idx, lines[idx])
            hits <- c(hits, add)
          }
        }
        if (!length(hits)) return("No matches.")
        if (length(hits) > limit) hits <- hits[seq_len(limit)]
        bebel_agent_format_value(paste(hits, collapse = "\n"), max_chars)
      }
    )
  )
  if (!isTRUE(allow_eval)) {
    tools$r_eval <- NULL
    tools$r_plot <- NULL
  }
  tools
}

#' Create an R-native Rbebelm agent session
#'
#' `bebel_r_agent()` is a higher-level layer inspired by R console agents. It
#' keeps one BebeLM agent, a private tool context, and a small R
#' tool catalog together so the same object can be driven by a console loop or
#' by the JSON-RPC server.
#'
#' @param model A `BebelModel` object.
#' @param system_prompt System prompt. `NULL` builds a default prompt including
#'   the tool catalog.
#' @param tools Tool catalog. Defaults to [bebel_default_r_tools()].
#' @param env Environment exposed to R tools.
#' @param cwd Working directory for file tools.
#' @param allow_eval Whether to include `r_eval` and `r_plot` tools that execute
#'   R code and render plots. Defaults to `TRUE`; set `FALSE` to start read-only.
#' @param prompt_detail Tool prompt detail. `"compact"` is faster for console
#'   use; `"full"` includes descriptions for every argument.
#' @param greedy,max_gen,max_context,max_think,temperature,top_k,repeat_penalty
#'   Generation options passed to [bebel_agent()].
#' @return A `bebelRAgent` environment.
#' @export
bebel_r_agent <- function(
  model,
  system_prompt = NULL,
  tools = NULL,
  env = .GlobalEnv,
  cwd = getwd(),
  allow_eval = TRUE,
  prompt_detail = c("compact", "full"),
  greedy = FALSE,
  max_gen = 512,
  max_context = 4096,
  max_think = 64,
  temperature = 0.8,
  top_k = 50,
  repeat_penalty = 1.1
) {
  prompt_detail <- match.arg(prompt_detail)
  if (is.null(tools)) tools <- bebel_default_r_tools(env = env, cwd = cwd, allow_eval = allow_eval)
  tools <- bebel_agent_normalize_tools(tools)
  if (is.null(system_prompt)) system_prompt <- bebel_agent_default_system(tools, detail = prompt_detail)

  agent <- bebel_agent(
    model,
    greedy = greedy,
    max_gen = max_gen,
    max_context = max_context,
    max_think = max_think,
    temperature = temperature,
    top_k = top_k,
    repeat_penalty = repeat_penalty
  )
  bebel_append_system(agent, system_prompt, tools = bebel_agent_as_bebel_tools(tools))

  x <- new.env(parent = emptyenv())
  x$model <- model
  x$agent <- agent
  x$system_prompt <- system_prompt
  x$tools <- tools
  x$context <- new.env(parent = emptyenv())
  x$context$env <- env
  x$context$cwd <- cwd
  x$allow_eval <- isTRUE(allow_eval)
  x$prompt_detail <- prompt_detail
  x$max_chars <- getOption("Rbebelm.agent.max_chars", 4000L)
  x$history <- list()
  x$turns <- list()
  x$created_at <- Sys.time()
  class(x) <- c("bebelRAgent", "environment")
  x
}

#' @export
print.bebelRAgent <- function(x, ...) {
  cat("<bebelRAgent>\n")
  cat("  tools: ", paste(names(x$tools), collapse = ", "), "\n", sep = "")
  info <- bebel_agent_info(x$agent)
  cat("  history tokens: ", info$history_tokens, "\n", sep = "")
  invisible(x)
}

#' Run one user turn through an Rbebelm R agent
#'
#' @param session A `bebelRAgent` from [bebel_r_agent()].
#' @param prompt User prompt.
#' @param max_steps Maximum assistant/tool iterations.
#' @param on_event Optional BebeLM event callback.
#' @param hooks Optional hooks passed to [bebel_agent_run()].
#' @param check_interrupt Check for Ctrl-C during generation.
#' @return A `bebelRAgentTurn` list.
#' @export
bebel_r_agent_turn <- function(session, prompt, max_steps = 4L, on_event = NULL, hooks = list(), check_interrupt = TRUE) {
  bebel_agent_layer_stopif(inherits(session, "bebelRAgent"), "session must be a bebelRAgent")
  bebel_append_user(session$agent, prompt)
  run <- bebel_agent_run(
    session$agent,
    tools = bebel_agent_as_bebel_tools(session$tools),
    context = session$context,
    hooks = hooks,
    max_steps = max_steps,
    on_event = on_event,
    check_interrupt = check_interrupt
  )
  text <- if (length(run$turns)) run$turns[[length(run$turns)]]$text %||% "" else ""
  out <- structure(
    list(prompt = prompt, text = text, run = run, transcript = bebel_transcript(session$agent)),
    class = "bebelRAgentTurn"
  )
  session$turns[[length(session$turns) + 1L]] <- out
  session$history[[length(session$history) + 1L]] <- list(role = "user", content = prompt)
  session$history[[length(session$history) + 1L]] <- list(role = "assistant", content = text)
  out
}

#' @export
print.bebelRAgentTurn <- function(x, ...) {
  cat("<bebelRAgentTurn>\n")
  cat(x$text, "\n", sep = "")
  invisible(x)
}

#' Clear an Rbebelm R agent session
#'
#' @param session A `bebelRAgent`.
#' @return Invisibly returns `session`.
#' @export
bebel_r_agent_clear <- function(session) {
  bebel_agent_layer_stopif(inherits(session, "bebelRAgent"), "session must be a bebelRAgent")
  bebel_clear(session$agent)
  bebel_append_system(session$agent, session$system_prompt, tools = bebel_agent_as_bebel_tools(session$tools))
  session$history <- list()
  session$turns <- list()
  invisible(session)
}

bebel_r_agent_set_eval <- function(session, loop = NULL, allow_eval = TRUE) {
  bebel_agent_layer_stopif(inherits(session, "bebelRAgent"), "session must be a bebelRAgent")
  session$allow_eval <- isTRUE(allow_eval)
  session$tools <- bebel_agent_normalize_tools(bebel_default_r_tools(
    env = session$context$env,
    cwd = session$context$cwd,
    allow_eval = session$allow_eval,
    max_chars = session$max_chars %||% 4000L
  ))
  session$system_prompt <- bebel_agent_default_system(session$tools, detail = session$prompt_detail %||% "compact")
  bebel_append_system(session$agent, session$system_prompt, tools = bebel_agent_as_bebel_tools(session$tools))
  if (!is.null(loop)) {
    loop$user_tools <- bebel_agent_as_bebel_tools(session$tools)
    bebel_loop_rebuild_catalogs(loop)
    bebel_loop_emit(loop, "catalog_changed", reason = if (session$allow_eval) "eval_enabled" else "eval_disabled", catalog = bebel_loop_catalog(loop))
  }
  invisible(session)
}

bebel_r_eval_text <- function(code, envir, max_chars = getOption("Rbebelm.console.r_output_chars", 4000L)) {
  if (!nzchar(trimws(code))) return("Usage: /r <R code>")
  exprs <- parse(text = code, srcfile = NULL)
  value <- NULL
  output <- utils::capture.output({
    for (expr in exprs) {
      result <- withVisible(eval(expr, envir = envir))
      value <- result$value
      if (isTRUE(result$visible)) print(result$value)
    }
  }, type = "output")
  if (length(output)) {
    bebel_agent_format_value(paste(output, collapse = "\n"), max_chars)
  } else if (is.null(value)) {
    "NULL"
  } else {
    bebel_agent_format_value(value, max_chars)
  }
}

bebel_r_agent_loop_extension <- function(session) {
  bebel_agent_layer_stopif(inherits(session, "bebelRAgent"), "session must be a bebelRAgent")
  command_help <- function(args, loop, context) {
    bebel_format_command_catalog(bebel_loop_command_catalog(loop))
  }
  bebel_extension(
    "r-agent-commands",
    commands = list(
      help = bebel_loop_command("help", command_help, description = "Show slash commands.", usage = "/help"),
      commands = bebel_loop_command("commands", command_help, description = "List slash commands.", usage = "/commands"),
      tools = bebel_loop_command("tools", function(args, loop, context) {
        catalog <- bebel_agent_tool_catalog(session$tools)
        bebel_format_name_description_catalog("Model tools", catalog$name, catalog$description, catalog$name)
      }, description = "List model tools advertised by the R agent.", usage = "/tools"),
      state = bebel_loop_command("state", function(args, loop, context) {
        s <- bebel_loop_state(loop)
        paste(
          sprintf("state: %s", s$state),
          sprintf("turns: %d", s$turns),
          sprintf("tool calls: %d", s$tool_calls),
          sprintf("commands: %s", paste(s$commands, collapse = ", ")),
          sprintf("tools: %s", paste(names(loop$tools), collapse = ", ")),
          sep = "\n"
        )
      }, description = "Show loop state.", usage = "/state"),
      transcript = bebel_loop_command("transcript", function(args, loop, context) {
        bebel_transcript(session$agent)
      }, description = "Show backend transcript.", usage = "/transcript"),
      graphics = bebel_loop_command("graphics", function(args, loop, context) {
        value <- trimws(args)
        if (!nzchar(value)) {
          current <- bebel_graphics_device()
          return(paste(
            sprintf("graphics device: %s", current),
            "usage: /graphics native|png|jgd|devout-ascii|auto",
            "auto chooses jgd when JGD_SOCKET+jgd are available, native in interactive R consoles, otherwise png.",
            sep = "\n"
          ))
        }
        value <- tolower(value)
        if (!value %in% c("auto", "native", "png", "jgd", "devout-ascii", "devout", "ascii", "devout_ascii")) {
          stop("unknown graphics device; use auto, native, png, jgd, or devout-ascii", call. = FALSE)
        }
        options(Rbebelm.graphics.device = value)
        sprintf("graphics device set to: %s", bebel_graphics_device(value))
      }, description = "Show or set the R graphics device used by r_plot and /rplot.", usage = "/graphics [auto|native|png|jgd|devout-ascii]"),
      clear = bebel_loop_command("clear", function(args, loop, context) {
        bebel_r_agent_clear(session)
        loop$turns <- list()
        loop$tool_calls <- list()
        loop$observations <- list()
        loop$user_messages <- list()
        loop$queue <- list(steering = character(), followUp = character())
        bebel_loop_emit(loop, "session_clear")
        "Cleared."
      }, description = "Clear transcript, loop state, and queues.", usage = "/clear"),
      `allow-eval` = bebel_loop_command("allow-eval", function(args, loop, context) {
        bebel_r_agent_set_eval(session, loop, allow_eval = TRUE)
        "Enabled model tools r_eval and r_plot for subsequent turns."
      }, description = "Enable model-side R eval and plotting tools.", usage = "/allow-eval"),
      `eval-on` = bebel_loop_command("eval-on", function(args, loop, context) {
        bebel_r_agent_set_eval(session, loop, allow_eval = TRUE)
        "Enabled model tools r_eval and r_plot for subsequent turns."
      }, description = "Enable model-side R eval and plotting tools.", usage = "/eval-on"),
      `no-eval` = bebel_loop_command("no-eval", function(args, loop, context) {
        bebel_r_agent_set_eval(session, loop, allow_eval = FALSE)
        "Disabled model tools r_eval and r_plot for subsequent turns. Direct /r and /rplot remain available."
      }, description = "Disable model-side R eval and plotting tools.", usage = "/no-eval"),
      `eval-off` = bebel_loop_command("eval-off", function(args, loop, context) {
        bebel_r_agent_set_eval(session, loop, allow_eval = FALSE)
        "Disabled model tools r_eval and r_plot for subsequent turns. Direct /r and /rplot remain available."
      }, description = "Disable model-side R eval and plotting tools.", usage = "/eval-off"),
      r = bebel_loop_command("r", function(args, loop, context) {
        bebel_r_eval_text(args, session$context$env)
      }, description = "Evaluate R code directly in the agent environment.", usage = "/r <R code>"),
      rplot = bebel_loop_command("rplot", function(args, loop, context) {
        code <- trimws(args)
        if (!nzchar(code)) {
          code <- "plot(1:10, (1:10)^2, type = 'b', main = 'Simple plot', xlab = 'x', ylab = 'x^2')"
        }
        exprs <- parse(text = code, srcfile = NULL)
        bebel_graphics_render_plot(exprs, session$context$env, cwd = session$context$cwd)
      }, description = "Render R plotting code using the configured R graphics device; no args creates a simple plot.", usage = "/rplot [plot-code]")
    )
  )
}

bebel_console_input_complete <- function(text) {
  tryCatch({
    parse(text = text, srcfile = FALSE)
    TRUE
  }, error = function(e) {
    msg <- conditionMessage(e)
    if (grepl("unexpected end of input", msg, fixed = TRUE)) FALSE else stop(e)
  })
}

bebel_console_open_input <- function() {
  if (interactive()) NULL else file("stdin", open = "r")
}

bebel_console_close_input <- function(con) {
  if (!is.null(con)) close(con)
  invisible(NULL)
}

bebel_console_read_line <- function(prompt = "", input_con = NULL) {
  if (is.null(input_con)) {
    readline(prompt)
  } else {
    cat(prompt)
    utils::flush.console()
    line <- readLines(input_con, n = 1L, warn = FALSE)
    if (!length(line)) character() else line[[1L]]
  }
}

bebel_console_read_r <- function(seed = "", input_con = NULL) {
  lines <- character()
  if (nzchar(seed)) lines <- seed
  repeat {
    if (length(lines) && bebel_console_input_complete(lines)) return(parse(text = lines, srcfile = NULL))
    line <- bebel_console_read_line(if (length(lines)) "R+ " else "R> ", input_con = input_con)
    if (!length(line)) return(NULL)
    lines <- c(lines, line)
  }
}

bebel_console_print_capped <- function(lines, max_lines = getOption("Rbebelm.console.r_output_lines", 20L), max_chars = getOption("Rbebelm.console.r_output_chars", 4000L)) {
  if (!length(lines)) return(invisible(FALSE))
  max_lines <- as.integer(max_lines %||% 20L)
  if (is.na(max_lines) || max_lines < 1L) max_lines <- 20L
  max_chars <- as.integer(max_chars %||% 4000L)
  if (is.na(max_chars) || max_chars < 1L) max_chars <- 4000L

  text <- paste(lines, collapse = "\n")
  truncated_lines <- length(lines) > max_lines
  truncated_chars <- nchar(text, type = "chars") > max_chars
  if (truncated_lines) {
    lines <- utils::head(lines, max_lines)
    text <- paste(lines, collapse = "\n")
  }
  if (nchar(text, type = "chars") > max_chars) {
    text <- substr(text, 1L, max_chars)
    truncated_chars <- TRUE
  }
  cat(text, "\n", sep = "")
  if (truncated_lines || truncated_chars) {
    cat(sprintf("[R output truncated: showing first %d line(s), %d char(s); assign large objects with /r x <- value]\n", max_lines, max_chars))
  }
  invisible(TRUE)
}

bebel_console_eval_r <- function(exprs, envir) {
  value <- NULL
  for (expr in exprs) {
    result <- NULL
    output <- utils::capture.output({
      result <- withVisible(eval(expr, envir = envir))
      value <- result$value
      if (isTRUE(result$visible)) print(result$value)
    }, type = "output")
    bebel_console_print_capped(output)
  }
  invisible(value)
}

bebel_console_plot_path <- function(cwd = getwd()) {
  root <- normalizePath(cwd, mustWork = FALSE)
  plot_dir <- file.path(root, "rbebelm-plots")
  dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
  tempfile("plot-", tmpdir = plot_dir, fileext = ".png")
}

bebel_console_save_plot <- function(exprs, envir, cwd = getwd(), width = 800L, height = 600L) {
  width <- suppressWarnings(as.integer(width %||% 800L))
  height <- suppressWarnings(as.integer(height %||% 600L))
  width <- if (length(width)) width[[1L]] else NA_integer_
  height <- if (length(height)) height[[1L]] else NA_integer_
  if (is.na(width) || width < 100L) width <- 800L
  if (is.na(height) || height < 100L) height <- 600L
  path <- bebel_console_plot_path(cwd)
  opened <- FALSE
  grDevices::png(filename = path, width = width, height = height)
  opened <- TRUE
  on.exit({
    if (opened) grDevices::dev.off()
  }, add = TRUE)
  for (expr in exprs) eval(expr, envir = envir)
  grDevices::dev.off()
  opened <- FALSE
  normalizePath(path, mustWork = FALSE)
}

bebel_agent_run_stats <- function(run) {
  turns <- run$turns %||% list()
  if (!length(turns)) {
    return(list(stop = NA_character_, prompt_tokens = 0L, generated_tokens = 0L,
                prefill_seconds = 0, decode_seconds = 0, prefill_tps = NA_real_,
                decode_tps = NA_real_, turns = 0L, tool_calls = length(run$tool_calls %||% list())))
  }
  nums <- function(name) vapply(turns, function(x) as.numeric(x[[name]] %||% 0), numeric(1))
  prompt_tokens <- sum(nums("prompt_tokens"))
  generated_tokens <- sum(nums("generated_tokens"))
  prefill_seconds <- sum(nums("prefill_seconds"))
  decode_seconds <- sum(nums("decode_seconds"))
  list(
    stop = turns[[length(turns)]]$stop %||% NA_character_,
    prompt_tokens = as.integer(prompt_tokens),
    generated_tokens = as.integer(generated_tokens),
    prefill_seconds = prefill_seconds,
    decode_seconds = decode_seconds,
    prefill_tps = if (prefill_seconds > 0) prompt_tokens / prefill_seconds else NA_real_,
    decode_tps = if (decode_seconds > 0) generated_tokens / decode_seconds else NA_real_,
    turns = length(turns),
    tool_calls = length(run$tool_calls %||% list())
  )
}

bebel_format_agent_run_stats <- function(run) {
  s <- bebel_agent_run_stats(run)
  sprintf(
    "[stats] stop=%s; turns=%d; tools=%d; tokens=%d generated, %d prompt; prefill=%.1f tok/s; decode=%.2f tok/s",
    s$stop, s$turns, s$tool_calls, s$generated_tokens, s$prompt_tokens,
    s$prefill_tps, s$decode_tps
  )
}

bebel_r_agent_console_commands <- function() {
  list(
    help = bebel_console_command("help", function(args, session, input_con, commands, ...) {
      catalog <- bebel_console_command_catalog(commands)
      cat("Commands:\n")
      for (i in seq_len(nrow(catalog))) {
        alias <- if (nzchar(catalog$aliases[[i]])) paste0(" (aliases: ", catalog$aliases[[i]], ")") else ""
        cat("  ", catalog$usage[[i]], alias, " - ", catalog$description[[i]], "\n", sep = "")
      }
      cat("Use /r <code> to evaluate R directly in the configured environment.\n")
      cat("Use /graphics native|png|jgd|devout-ascii to choose plot handling.\n")
      cat("Large /r output is truncated; assign objects with /r x <- value.\n")
    }, description = "Show console commands.", usage = "/help"),
    tools = bebel_console_command("tools", function(args, session, input_con, commands, ...) {
      print(bebel_agent_tool_catalog(session$tools))
    }, description = "List model tools advertised by the R agent.", usage = "/tools"),
    graphics = bebel_console_command("graphics", function(args, session, input_con, commands, ...) {
      value <- trimws(args)
      if (!nzchar(value)) {
        cat("graphics device: ", bebel_graphics_device(), "\n", sep = "")
        cat("usage: /graphics native|png|jgd|devout-ascii|auto\n")
        return(invisible(NULL))
      }
      value <- tolower(value)
      if (!value %in% c("auto", "native", "png", "jgd", "devout-ascii", "devout", "ascii", "devout_ascii")) {
        message("Unknown graphics device. Use auto, native, png, jgd, or devout-ascii.")
        return(invisible(NULL))
      }
      options(Rbebelm.graphics.device = value)
      cat("graphics device set to: ", bebel_graphics_device(value), "\n", sep = "")
    }, description = "Show or set the R graphics device used by r_plot and /rplot.", usage = "/graphics [auto|native|png|jgd|devout-ascii]"),
    r = bebel_console_command("r", function(args, session, input_con, commands, ...) {
      exprs <- tryCatch(bebel_console_read_r(trimws(args), input_con = input_con), error = function(e) {
        message("R parse error: ", conditionMessage(e))
        NULL
      })
      if (!is.null(exprs)) {
        tryCatch(bebel_console_eval_r(exprs, session$context$env), error = function(e) {
          message("R error: ", conditionMessage(e))
        })
      }
    }, description = "Evaluate R code directly in the configured environment.", usage = "/r <R code>"),
    rplot = bebel_console_command("rplot", function(args, session, input_con, commands, ...) {
      exprs <- tryCatch(bebel_console_read_r(trimws(args), input_con = input_con), error = function(e) {
        message("R parse error: ", conditionMessage(e))
        NULL
      })
      if (!is.null(exprs)) {
        tryCatch({
          out <- bebel_graphics_render_plot(exprs, session$context$env, cwd = session$context$cwd)
          cat(bebel_agent_tool_text(out), "\n", sep = "")
        }, error = function(e) {
          message("R plot error: ", conditionMessage(e))
        })
      }
    }, description = "Draw R plotting code with the configured graphics device.", usage = "/rplot [plot-code]"),
    transcript = bebel_console_command("transcript", function(args, session, input_con, commands, ...) {
      cat(bebel_transcript(session$agent), "\n", sep = "")
    }, description = "Show backend transcript.", usage = "/transcript"),
    clear = bebel_console_command("clear", function(args, session, input_con, commands, ...) {
      bebel_r_agent_clear(session)
      cat("Cleared.\n")
    }, description = "Clear transcript and agent state.", usage = "/clear"),
    quit = bebel_console_command("quit", function(args, session, input_con, commands, ...) {
      list(quit = TRUE)
    }, description = "Exit the console.", usage = "/quit", aliases = c("q", "exit"))
  )
}

#' Start an interactive Rbebelm console agent
#'
#' @param session A `bebelRAgent`.
#' @param prompt Prompt string.
#' @param max_steps Maximum assistant/tool iterations per user prompt.
#' @param show_stats Whether to print token/timing stats after each turn.
#' @param blank_limit Number of consecutive blank inputs before exiting. Set to `Inf` to never auto-exit on blanks.
#' @return Invisibly returns `session`.
#' @export
bebel_r_agent_console <- function(session, prompt = "bebel> ", max_steps = 4L, show_stats = TRUE, blank_limit = 10L) {
  bebel_agent_layer_stopif(inherits(session, "bebelRAgent"), "session must be a bebelRAgent")
  if (!interactive() && !isatty(stdin())) stop("bebel_r_agent_console() requires an interactive terminal", call. = FALSE)
  blank_limit <- suppressWarnings(as.numeric(blank_limit))
  blank_limit <- if (length(blank_limit)) blank_limit[[1L]] else NA_real_
  if (is.na(blank_limit) || blank_limit < 1) blank_limit <- 10
  cat("RbebelM R agent. Commands: /help, /tools, /graphics, /r, /rplot, /transcript, /clear, /quit\n")
  cat("Type a message and press Enter; blank lines are ignored.\n")
  input_con <- bebel_console_open_input()
  on.exit(bebel_console_close_input(input_con), add = TRUE)
  commands <- bebel_r_agent_console_commands()
  blank_count <- 0L
  repeat {
    quit <- FALSE
    interrupted <- FALSE
    tryCatch({
      line <- bebel_console_read_line(prompt, input_con = input_con)
      if (!length(line)) {
        quit <- TRUE
      } else {
        line_trim <- trimws(line)
        if (!nzchar(line_trim)) {
          blank_count <- blank_count + 1L
          if (is.finite(blank_limit) && blank_count >= blank_limit) {
            cat(sprintf("[exiting after %d blank inputs]\n", blank_count))
            quit <- TRUE
          } else if (blank_count %% 3L == 0L) {
            cat("[blank input ignored; type a message, /help, or /quit]\n")
          }
        } else {
          blank_count <- 0L
          if (startsWith(line_trim, "/")) {
            command_result <- bebel_console_dispatch_command(line_trim, commands, session, input_con)
            if (isTRUE(command_result$quit)) {
              quit <- TRUE
            } else if (!isTRUE(command_result$handled)) {
              cat("Unknown command. Use /help.\n")
            }
          } else {
            hooks <- list(
              tool_request = function(call, ...) cat(sprintf("\n[tool] %s\n", call$name)),
              tool_result = function(call, result, ...) cat(sprintf("[tool result] %s\n", bebel_agent_tool_text(result))),
              tool_error = function(call, error, ...) cat(sprintf("[tool error] %s: %s\n", call$name, conditionMessage(error)))
            )
            cat("[generating]\n")
            turn <- bebel_r_agent_turn(session, line, max_steps = max_steps, on_event = bebel_console_event(), hooks = hooks)
            last_turn <- if (length(turn$run$turns)) turn$run$turns[[length(turn$run$turns)]] else NULL
            if (isTRUE(show_stats)) cat("\n", bebel_format_agent_run_stats(turn$run), "\n", sep = "")
            if (!is.null(last_turn) && identical(last_turn$stop, "max_new")) {
              cat("[stopped at max_gen; recreate the agent with a larger max_gen for longer replies]\n")
            }
            cat("\n")
          }
        }
      }
    }, interrupt = function(e) {
      interrupted <<- TRUE
      cat("\n[interrupted; type /quit to exit]\n")
    })
    if (quit) break
    if (interrupted) next
  }
  invisible(session)
}

#' Launch an R-native Rbebelm console from weights
#'
#' Convenience wrapper for loading a model, creating a [bebel_r_agent()], and
#' entering [bebel_r_agent_console()]. This keeps the loaded model object local
#' to the launcher while the agent tools, `/r`, and `/rplot` commands share `env`.
#'
#' @param weights GGUF weights file. Defaults to `BEBELM_WEIGHTS_FILE`, then
#'   `"LFM2.5-8B-A1B-Q4_K_M.gguf"` in the working directory.
#' @param num_threads Optional Rayon thread count passed to [bebel_model_load()].
#' @param env Environment shared by `/r`, `/rplot`, `r_objects`, and optional code-evaluation tools.
#' @param cwd Working directory for file tools and `/rplot` output.
#' @param allow_eval Whether to include `r_eval` and `r_plot` tools that the model can call.
#' @param greedy,max_gen,max_context,max_think,temperature,top_k,repeat_penalty
#'   Generation options passed to [bebel_r_agent()].
#' @param prompt Prompt string for [bebel_r_agent_console()].
#' @param max_steps Maximum assistant/tool iterations per user prompt.
#' @param show_stats Whether to print token/timing stats after each turn.
#' @param blank_limit Number of consecutive blank inputs before exiting the console. Set to `Inf` to never auto-exit on blanks.
#' @param prompt_detail Tool prompt detail passed to [bebel_r_agent()].
#' @return Invisibly returns the `bebelRAgent` session after the console exits.
#' @export
bebel_r_agent_start <- function(
  weights = Sys.getenv("BEBELM_WEIGHTS_FILE", "LFM2.5-8B-A1B-Q4_K_M.gguf"),
  num_threads = as.numeric(Sys.getenv("BEBELM_NUM_THREADS", "2")),
  env = .GlobalEnv,
  cwd = getwd(),
  allow_eval = TRUE,
  greedy = TRUE,
  max_gen = as.numeric(Sys.getenv("BEBELM_AGENT_MAX_GEN", "256")),
  max_context = 4096,
  max_think = as.numeric(Sys.getenv("BEBELM_AGENT_MAX_THINK", "48")),
  temperature = 0.8,
  top_k = 50,
  repeat_penalty = 1.1,
  prompt = "bebel> ",
  max_steps = 4L,
  show_stats = TRUE,
  blank_limit = 10L,
  prompt_detail = c("compact", "full")
) {
  prompt_detail <- match.arg(prompt_detail)
  model <- bebel_model_load(weights, num_threads = num_threads)
  session <- bebel_r_agent(
    model,
    env = env,
    cwd = cwd,
    allow_eval = allow_eval,
    greedy = greedy,
    max_gen = max_gen,
    max_context = max_context,
    max_think = max_think,
    temperature = temperature,
    top_k = top_k,
    repeat_penalty = repeat_penalty,
    prompt_detail = prompt_detail
  )
  bebel_r_agent_console(session, prompt = prompt, max_steps = max_steps, show_stats = show_stats, blank_limit = blank_limit)
  invisible(session)
}

bebel_rpc_json <- function(x) {
  bebel_json_write(x)
}

bebel_rpc_response <- function(id, result = NULL, error = NULL) {
  if (is.null(error)) {
    list(jsonrpc = "2.0", id = id, result = result)
  } else {
    list(jsonrpc = "2.0", id = id, error = error)
  }
}

bebel_rpc_handle <- function(session, req) {
  method <- req$method %||% ""
  id <- req$id %||% NULL
  params <- req$params %||% list()
  result <- tryCatch({
    switch(
      method,
      "session/info" = {
        c(bebel_agent_info(session$agent), list(tools = names(session$tools)))
      },
      "tools/list" = {
        list(tools = unname(lapply(session$tools, function(tool) {
          list(name = tool$name, description = tool$description, inputSchema = bebel_agent_tool_schema(tool$params))
        })))
      },
      "session/transcript" = {
        list(transcript = bebel_transcript(session$agent))
      },
      "session/clear" = {
        bebel_r_agent_clear(session)
        list(ok = TRUE)
      },
      "turn" = {
        prompt <- params$prompt %||% stop("turn requires params$prompt", call. = FALSE)
        turn <- bebel_r_agent_turn(session, prompt, max_steps = as.integer(params$max_steps %||% 4L), on_event = NULL)
        list(text = turn$text, tool_calls = turn$run$tool_calls, backend_info = turn$run$backend_info)
      },
      stop("unknown method: ", method, call. = FALSE)
    )
  }, error = function(e) {
    structure(list(code = -32000L, message = conditionMessage(e)), class = "bebel_rpc_error")
  })
  if (inherits(result, "bebel_rpc_error")) {
    bebel_rpc_response(id, error = unclass(result))
  } else {
    bebel_rpc_response(id, result = result)
  }
}

#' Serve an Rbebelm R agent over JSON-RPC
#'
#' This optional SDK surface uses `nanonext` to expose the same `bebelRAgent`
#' object used by the console. JSON parsing/serialization uses imported `yyjsonr`.
#' It is intentionally small and not an OpenAI API:
#' clients call JSON-RPC methods such as `turn`, `tools/list`, and
#' `session/transcript`.
#'
#' @param session A `bebelRAgent`.
#' @param url URL to listen on, e.g. `"http://127.0.0.1:8080"`.
#' @return A `nanoServer` object from `nanonext`.
#' @export
bebel_r_agent_rpc_server <- function(session, url = "http://127.0.0.1:8080") {
  bebel_agent_layer_stopif(inherits(session, "bebelRAgent"), "session must be a bebelRAgent")
  bebel_agent_require("nanonext")

  handlers <- list(
    nanonext::handler("/health", function(req) {
      list(status = 200L, headers = c("Content-Type" = "application/json"), body = bebel_rpc_json(list(ok = TRUE)))
    }, method = "GET"),
    nanonext::handler("/rpc", function(req) {
      body <- rawToChar(req$body %||% raw())
      parsed <- tryCatch(bebel_json_read(body), error = function(e) NULL)
      if (is.null(parsed)) {
        response <- bebel_rpc_response(NULL, error = list(code = -32700L, message = "parse error"))
      } else {
        response <- bebel_rpc_handle(session, parsed)
      }
      list(status = 200L, headers = c("Content-Type" = "application/json"), body = bebel_rpc_json(response))
    }, method = "POST")
  )
  nanonext::http_server(url = url, handlers = handlers)
}
