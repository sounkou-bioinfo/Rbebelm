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
  if (identical(detail, "compact")) {
    return(paste(
      "Concise R assistant. Use tools only when needed; never invent tool results.",
      bebel_agent_tools_prompt(tools, detail = detail),
      sep = "\n"
    ))
  }

  paste(
    "You are an R-native assistant running inside the user's R session.",
    "Be concise and use tools only when they are needed to inspect files, R objects, documentation, or code results.",
    "Do not invent tool results. If a tool is needed, emit only a tool call in the documented format.",
    bebel_agent_tools_prompt(tools, detail = detail),
    sep = "\n\n"
  )
}

#' Built-in R session tools for the Rbebelm agent layer
#'
#' The default catalog is intentionally small. It exposes read-only file and R
#' session inspection tools plus optional R evaluation. These are ordinary R
#' functions and run in the current R process.
#'
#' @param env Environment used by `r_objects` and `r_eval`.
#' @param cwd Working directory for file tools.
#' @param allow_eval Whether to include the `r_eval` tool. If `FALSE`, `r_eval`
#'   is not advertised to the model.
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
      "List files under a directory.",
      params = list(
        path = list(type = "string", description = "Directory path relative to the agent cwd.", required = FALSE),
        pattern = list(type = "string", description = "Optional regex filter.", required = FALSE),
        recursive = list(type = "boolean", description = "Whether to recurse.", required = FALSE),
        limit = list(type = "integer", description = "Maximum number of entries.", required = FALSE)
      ),
      fun = function(args, context, call) {
        path <- resolve_path(args$path %||% ".")
        if (!dir.exists(path)) return(paste("Directory not found:", path))
        limit <- as.integer(args$limit %||% 200L)
        if (is.na(limit) || limit < 1L) limit <- 200L
        entries <- list.files(path, pattern = args$pattern %||% NULL, recursive = isTRUE(args$recursive), all.files = TRUE, no.. = TRUE, full.names = TRUE)
        entries <- sort(entries)
        if (!length(entries)) return(paste("No files found in", path))
        rel <- strip_root(entries, path)
        if (length(rel) > limit) rel <- c(rel[seq_len(limit)], sprintf("... %d more", length(entries) - limit))
        bebel_agent_format_value(paste(rel, collapse = "\n"), max_chars)
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
          lines <- tryCatch(readLines(f, warn = FALSE), error = function(e) character())
          if (!length(lines)) next
          idx <- grep(args$pattern, lines)
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
  if (!isTRUE(allow_eval)) tools$r_eval <- NULL
  tools
}

#' Create an R-native Rbebelm agent session
#'
#' `bebel_r_agent()` is a higher-level layer inspired by R console agent
#' harnesses. It keeps one BebeLM agent, a private tool context, and a small R
#' tool catalog together so the same object can be driven by a console loop or
#' by the JSON-RPC server.
#'
#' @param model A `BebelModel` object.
#' @param system_prompt System prompt. `NULL` builds a default prompt including
#'   the tool catalog.
#' @param tools Tool catalog. Defaults to [bebel_default_r_tools()].
#' @param env Environment exposed to R tools.
#' @param cwd Working directory for file tools.
#' @param allow_eval Whether to include an `r_eval` tool that executes code.
#' @param prompt_style Tool prompt verbosity. `"compact"` is faster for console
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
  allow_eval = FALSE,
  prompt_style = c("compact", "full"),
  greedy = FALSE,
  max_gen = 512,
  max_context = 4096,
  max_think = 64,
  temperature = 0.8,
  top_k = 50,
  repeat_penalty = 1.1
) {
  prompt_style <- match.arg(prompt_style)
  if (is.null(tools)) tools <- bebel_default_r_tools(env = env, cwd = cwd, allow_eval = allow_eval)
  tools <- bebel_agent_normalize_tools(tools)
  if (is.null(system_prompt)) system_prompt <- bebel_agent_default_system(tools, detail = prompt_style)

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
  bebel_append_system(agent, system_prompt)

  x <- new.env(parent = emptyenv())
  x$model <- model
  x$agent <- agent
  x$system_prompt <- system_prompt
  x$tools <- tools
  x$context <- new.env(parent = emptyenv())
  x$context$env <- env
  x$context$cwd <- cwd
  x$history <- list()
  x$turns <- list()
  x$created_at <- Sys.time()
  class(x) <- c("bebelRAgent", "environment")
  x
}

#' @export
print.bebelRAgent <- function(x, ...) {
  cat("<bebelRAgent>\n")
  cat("  tools:", paste(names(x$tools), collapse = ", "), "\n")
  info <- bebel_agent_info(x$agent)
  cat("  history tokens:", info$history_tokens, "\n")
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
  bebel_append_system(session$agent, session$system_prompt)
  session$history <- list()
  session$turns <- list()
  invisible(session)
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

bebel_console_read_r <- function(seed = "") {
  lines <- character()
  if (nzchar(seed)) lines <- seed
  repeat {
    if (length(lines) && bebel_console_input_complete(lines)) return(parse(text = lines, srcfile = NULL))
    line <- readline(if (length(lines)) "R+ " else "R> ")
    if (!length(line)) return(NULL)
    lines <- c(lines, line)
  }
}

bebel_console_eval_r <- function(exprs, envir) {
  value <- NULL
  for (expr in exprs) {
    result <- withVisible(eval(expr, envir = envir))
    value <- result$value
    if (isTRUE(result$visible)) print(result$value)
  }
  invisible(value)
}

#' Start an interactive Rbebelm console agent
#'
#' @param session A `bebelRAgent`.
#' @param prompt Prompt string.
#' @param max_steps Maximum assistant/tool iterations per user prompt.
#' @return Invisibly returns `session`.
#' @export
bebel_r_agent_console <- function(session, prompt = "bebel> ", max_steps = 4L) {
  bebel_agent_layer_stopif(inherits(session, "bebelRAgent"), "session must be a bebelRAgent")
  if (!interactive()) stop("bebel_r_agent_console() requires an interactive R session", call. = FALSE)
  cat("RbebelM R agent. Commands: /help, /tools, /r, /transcript, /clear, /quit\n")
  repeat {
    line <- readline(prompt)
    if (!length(line)) break
    line_trim <- trimws(line)
    if (!nzchar(line_trim)) next
    if (startsWith(line_trim, "/")) {
      cmd <- tolower(strsplit(line_trim, "\\s+")[[1]][1])
      if (cmd %in% c("/q", "/quit", "/exit")) break
      if (cmd == "/help") {
        cat("Commands: /help /tools /r /transcript /clear /quit\n")
        cat("Use /r <code> to evaluate R directly in the configured environment.\n")
        next
      }
      if (cmd == "/tools") {
        print(bebel_agent_tool_catalog(session$tools))
        next
      }
      if (cmd == "/r") {
        code <- trimws(sub("^/r\\s*", "", line_trim))
        exprs <- tryCatch(bebel_console_read_r(code), error = function(e) {
          message("R parse error: ", conditionMessage(e))
          NULL
        })
        if (!is.null(exprs)) {
          tryCatch(bebel_console_eval_r(exprs, session$context$env), error = function(e) {
            message("R error: ", conditionMessage(e))
          })
        }
        next
      }
      if (cmd == "/transcript") {
        cat(bebel_transcript(session$agent), "\n", sep = "")
        next
      }
      if (cmd == "/clear") {
        bebel_r_agent_clear(session)
        cat("Cleared.\n")
        next
      }
      cat("Unknown command. Use /help.\n")
      next
    }
    hooks <- list(
      tool_request = function(call, ...) cat(sprintf("\n[tool] %s\n", call$name)),
      tool_result = function(call, result, ...) cat(sprintf("[tool result] %s\n", bebel_agent_tool_text(result))),
      tool_error = function(call, error, ...) cat(sprintf("[tool error] %s: %s\n", call$name, conditionMessage(error)))
    )
    cat("[generating]\n")
    turn <- bebel_r_agent_turn(session, line, max_steps = max_steps, on_event = bebel_console_event(), hooks = hooks)
    last_turn <- if (length(turn$run$turns)) turn$run$turns[[length(turn$run$turns)]] else NULL
    if (!is.null(last_turn) && identical(last_turn$stop, "max_new")) {
      cat("\n[stopped at max_gen; recreate the agent with a larger max_gen for longer replies]\n")
    }
    cat("\n")
  }
  invisible(session)
}

bebel_rpc_json <- function(x) {
  jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", pretty = FALSE)
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
        list(text = turn$text, tool_calls = turn$run$tool_calls, agent_info = turn$run$agent_info)
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
#' object used by the console. It is intentionally small and not an OpenAI API:
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
  bebel_agent_require("jsonlite")

  handlers <- list(
    nanonext::handler("/health", function(req) {
      list(status = 200L, headers = c("Content-Type" = "application/json"), body = bebel_rpc_json(list(ok = TRUE)))
    }, method = "GET"),
    nanonext::handler("/rpc", function(req) {
      body <- rawToChar(req$body %||% raw())
      parsed <- tryCatch(jsonlite::fromJSON(body, simplifyVector = FALSE), error = function(e) NULL)
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
