#' Select the Rbebelm native backend
#'
#' Must be called before loading a model or querying backend features.
#'
#' @param backend One of `"auto"`, `"scalar"`, `"avx2"`, `"avx512"`, or `"neon"`.
#' @return The requested backend name.
#' @export
rbebelm_set_backend <- function(backend = "auto") {
  backend <- match.arg(backend, c("auto", "scalar", "avx2", "avx512", "neon", "wasm_simd128"))
  .Call(Rbebelm_set_backend_impl, backend)
}

#' Inspect Rbebelm backend dispatch state
#'
#' @return A named list describing installed, supported, requested, and selected backends,
#'   with class `rbebelmBackendInfo`.
#' @export
rbebelm_backend_info <- function() {
  structure(.Call(Rbebelm_backend_info_impl), class = c("rbebelmBackendInfo", "list"))
}

#' Inspect CPU SIMD support used by backend dispatch
#'
#' @return A named list of logical CPU feature checks with class `rbebelmCpuidInfo`.
#' @export
rbebelm_cpuid_info <- function() {
  structure(.Call(Rbebelm_cpuid_info_impl), class = c("rbebelmCpuidInfo", "list"))
}

# Keep this wrapper in R/api.R so the generated savvy function gets a package
# class and a readable print method without editing R/000-wrappers.R.
rbebelm_backend_features <- function() {
  structure(.Call(savvy_rbebelm_backend_features__impl), class = c("rbebelmBackendFeatures", "list"))
}

format_bebel_yes_no <- function(x) {
  ifelse(isTRUE(x), "yes", "no")
}

#' @export
print.rbebelmBackendInfo <- function(x, ...) {
  cat("<Rbebelm backend dispatch>\n")
  cat("  mode:", x$dispatch_mode, "\n")
  cat("  requested:", x$requested_backend, "\n")
  cat("  selected:", x$selected_backend, "\n")
  cat("  loaded:", format_bebel_yes_no(x$backend_loaded), "\n")
  cat("  installed:", x$installed_backends, "\n")
  cat("  supported:", x$supported_backends, "\n")
  invisible(x)
}

#' @export
print.rbebelmCpuidInfo <- function(x, ...) {
  cat("<Rbebelm CPU features>\n")
  cat("  x86_64-v3:", format_bebel_yes_no(x$cpu_x86_64_v3), "\n")
  cat("  x86_64-v4:", format_bebel_yes_no(x$cpu_x86_64_v4), "\n")
  cat("  NEON:", format_bebel_yes_no(x$cpu_neon), "\n")
  cat("  ARM dotprod:", format_bebel_yes_no(x$cpu_dotprod), "\n")
  cat("  wasm simd128:", format_bebel_yes_no(x$cpu_wasm_simd128), "\n")
  invisible(x)
}

#' @export
print.rbebelmBackendFeatures <- function(x, ...) {
  cat("<Rbebelm backend features>\n")
  cat("  backend:", x$backend, "\n")
  cat("  target:", paste0(x$target_arch, "-", x$target_os), "\n")
  cat("  Rust crate:", paste0(x$rust_package, " ", x$rust_package_version), "\n")
  cat("  native SIMD feature:", format_bebel_yes_no(x$native_simd_feature), "\n")
  cat("  compiled features:\n")
  cat("    AVX2:", format_bebel_yes_no(x$compiled_avx2), "\n")
  cat("    AVX-512F:", format_bebel_yes_no(x$compiled_avx512f), "\n")
  cat("    NEON:", format_bebel_yes_no(x$compiled_neon), "\n")
  cat("    ARM dotprod:", format_bebel_yes_no(x$compiled_dotprod), "\n")
  cat("    wasm simd128:", format_bebel_yes_no(x$compiled_wasm_simd128), "\n")
  invisible(x)
}

#' Load a BebeLM GGUF model
#'
#' @param path Path to the GGUF weights file.
#' @param num_threads Optional Rayon global thread-pool size. This can only be set once per R process.
#' @return A `BebelModel` object.
#' @export
bebel_model_load <- function(path, num_threads = NULL) {
  BebelModel$load(path, num_threads = num_threads)
}

#' Tokenize text with a BebeLM model tokenizer
#'
#' @param model A `BebelModel` object.
#' @param text Text to encode.
#' @param add_bos Whether to prepend the BOS token.
#' @return Integer token ids.
#' @export
bebel_tokenize <- function(model, text, add_bos = TRUE) {
  if (!inherits(model, "BebelModel")) {
    stop("model must be a BebelModel", call. = FALSE)
  }
  model$encode(text, add_bos = add_bos)
}

#' Decode BebeLM token ids
#'
#' @param model A `BebelModel` object.
#' @param ids Integer token ids.
#' @return Decoded text.
#' @export
bebel_detokenize <- function(model, ids) {
  if (!inherits(model, "BebelModel")) {
    stop("model must be a BebelModel", call. = FALSE)
  }
  model$decode(as.integer(ids))
}

#' Create a persistent BebeLM agent
#'
#' A `BebelAgent` owns an independent token transcript and decode cache while
#' sharing the loaded model weights. This mirrors upstream `bebelm::agent::Agent`.
#'
#' @inheritParams bebel_generate
#' @return A `BebelAgent` object.
#' @export
bebel_agent <- function(
  model,
  greedy = FALSE,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
) {
  if (!inherits(model, "BebelModel")) {
    stop("model must be a BebelModel", call. = FALSE)
  }
  BebelAgent$new(
    model = model,
    greedy = greedy,
    max_gen = max_gen,
    max_context = max_context,
    max_think = max_think,
    temperature = temperature,
    top_k = top_k,
    repeat_penalty = repeat_penalty
  )
}

check_bebel_agent <- function(agent) {
  if (!inherits(agent, "BebelAgent")) {
    stop("agent must be a BebelAgent", call. = FALSE)
  }
  invisible(agent)
}

#' Inspect a BebeLM agent
#'
#' @param agent A `BebelAgent` object.
#' @return Named list of state and configuration.
#' @export
bebel_agent_info <- function(agent) {
  check_bebel_agent(agent)
  agent$info()
}

#' Configure a BebeLM agent
#'
#' @inheritParams bebel_agent
#' @param agent A `BebelAgent` object.
#' @return Updated agent info.
#' @export
bebel_agent_configure <- function(
  agent,
  greedy = NULL,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
) {
  check_bebel_agent(agent)
  agent$configure(
    greedy = greedy,
    max_gen = max_gen,
    max_context = max_context,
    max_think = max_think,
    temperature = temperature,
    top_k = top_k,
    repeat_penalty = repeat_penalty
  )
}

#' Append raw text to a BebeLM agent transcript
#'
#' @param agent A `BebelAgent` object.
#' @param text Raw text to append.
#' @return Invisibly returns `agent`.
#' @export
bebel_append <- function(agent, text) {
  check_bebel_agent(agent)
  agent$append(text)
  invisible(agent)
}

#' Append a ChatML system turn to a BebeLM agent transcript
#'
#' Appends `<|im_start|>system\n...<|im_end|>` framing. BebeLM upstream does
#' not expose a separate system-prompt channel; this helper provides the ChatML
#' system-role form for users who want to place an instruction before user
#' turns.
#'
#' @param agent A `BebelAgent` object.
#' @param message System instruction text.
#' @return Invisibly returns `agent`.
#' @export
bebel_append_system <- function(agent, message) {
  check_bebel_agent(agent)
  agent$append_system(message)
  invisible(agent)
}

#' Append a ChatML user turn to a BebeLM agent transcript
#'
#' @param agent A `BebelAgent` object.
#' @param message User message.
#' @return Invisibly returns `agent`.
#' @export
bebel_append_user <- function(agent, message) {
  check_bebel_agent(agent)
  agent$append_user(message)
  invisible(agent)
}

#' Append token ids to a BebeLM agent transcript
#'
#' @param agent A `BebelAgent` object.
#' @param ids Integer token ids.
#' @return Invisibly returns `agent`.
#' @export
bebel_append_tokens <- function(agent, ids) {
  check_bebel_agent(agent)
  agent$append_tokens(as.integer(ids))
  invisible(agent)
}

#' Generate a raw continuation from a BebeLM agent transcript
#'
#' @param agent A `BebelAgent` object.
#' @inheritParams bebel_generate
#' @return A classed generation result.
#' @export
bebel_agent_generate <- function(agent, on_event = bebel_console_event(), check_interrupt = TRUE) {
  check_bebel_agent(agent)
  on_event <- normalize_bebel_on_event(on_event)
  out <- agent$generate(check_interrupt = check_interrupt, on_event = on_event)
  class(out) <- c("bebelAgentGenerateResult", "bebelGeneration", class(out))
  out
}

#' Generate and close an assistant ChatML turn from a BebeLM agent
#'
#' @param agent A `BebelAgent` object.
#' @inheritParams bebel_generate
#' @return A classed generation result.
#' @export
bebel_assistant_turn <- function(agent, on_event = bebel_console_event(), check_interrupt = TRUE) {
  check_bebel_agent(agent)
  on_event <- normalize_bebel_on_event(on_event)
  out <- agent$assistant_turn(check_interrupt = check_interrupt, on_event = on_event)
  class(out) <- c("bebelAssistantTurnResult", "bebelGeneration", class(out))
  out
}

#' Clear a BebeLM agent transcript and caches
#'
#' Clears the conversation state while keeping the loaded model weights and the
#' agent's generation configuration. This is the helper form of `agent$clear()`.
#'
#' @param agent A `BebelAgent` object.
#' @return Updated agent info.
#' @export
bebel_clear <- function(agent) {
  check_bebel_agent(agent)
  agent$clear()
}

#' Return a BebeLM agent token transcript
#'
#' Returns the full token transcript currently held by the agent. This is the
#' helper form of `agent$history()`.
#'
#' @param agent A `BebelAgent` object.
#' @return Integer token ids.
#' @export
bebel_history <- function(agent) {
  check_bebel_agent(agent)
  agent$history()
}

#' Decode a BebeLM agent transcript
#'
#' Decodes the agent's full token transcript. This is the helper form of
#' `agent$transcript()`.
#'
#' @param agent A `BebelAgent` object.
#' @return Transcript text.
#' @export
bebel_transcript <- function(agent) {
  check_bebel_agent(agent)
  agent$transcript()
}


#' Append a ChatML tool result turn to a BebeLM agent transcript
#'
#' @param agent A `BebelAgent` object.
#' @param content Tool result content to append.
#' @return Invisibly returns `agent`.
#' @export
bebel_append_tool_result <- function(agent, content) {
  check_bebel_agent(agent)
  agent$append_tool_result(as.character(content)[1])
  invisible(agent)
}

#' Define a BebeLM R tool
#'
#' @param name Tool name exposed to the tool dispatcher.
#' @param fun Function to run. It is called as `fun(args = ..., context = ..., call = ...)`
#'   when it accepts those names, otherwise with progressively simpler fallbacks.
#' @param description Optional human-readable description.
#' @param schema Optional schema/metadata object for prompts or adapters.
#' @return A `bebelTool` object.
#' @export
bebel_tool <- function(name, fun, description = NULL, schema = NULL) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("tool name must be a single non-empty string", call. = FALSE)
  }
  if (!is.function(fun)) {
    stop("tool fun must be a function", call. = FALSE)
  }
  structure(
    list(name = name, fun = fun, description = description, schema = schema),
    class = "bebelTool"
  )
}

#' @export
print.bebelTool <- function(x, ...) {
  cat("<bebelTool>", x$name, "\n")
  if (!is.null(x$description)) cat("  ", x$description, "\n", sep = "")
  invisible(x)
}

normalize_bebel_tools <- function(tools) {
  if (is.null(tools)) return(list())
  if (inherits(tools, "bebelTool")) tools <- list(tools)
  if (!is.list(tools)) stop("tools must be a list of bebelTool objects or functions", call. = FALSE)
  out <- list()
  for (i in seq_along(tools)) {
    tool <- tools[[i]]
    if (inherits(tool, "bebelTool")) {
      name <- tool$name
    } else if (is.function(tool)) {
      name <- names(tools)[i]
      if (is.null(name) || !nzchar(name)) stop("function tools must be named", call. = FALSE)
      tool <- bebel_tool(name, tool)
    } else {
      stop("tools must contain bebelTool objects or functions", call. = FALSE)
    }
    out[[name]] <- tool
  }
  out
}


parse_bebel_call_args <- function(args) {
  args <- trimws(args)
  if (!nzchar(args)) return(list())
  if (grepl("^\\s*\\{", args)) {
    return(rbebelm_json_parse(args))
  }
  parts <- strsplit(args, "\\s*,\\s*", perl = TRUE)[[1]]
  out <- list()
  for (part in parts) {
    m <- regexec("^([A-Za-z_][A-Za-z0-9_.-]*)\\s*=\\s*(.*)$", trimws(part), perl = TRUE)
    hit <- regmatches(part, m)[[1]]
    if (!length(hit)) return(args)
    value <- trimws(hit[3])
    if (grepl('^".*"$', value) || grepl("^'.*'$", value)) {
      value <- substr(value, 2L, nchar(value) - 1L)
    } else if (grepl("^-?[0-9]+$", value)) {
      value <- as.integer(value)
    } else if (grepl("^-?[0-9]+\\.[0-9]+$", value)) {
      value <- as.numeric(value)
    } else if (identical(tolower(value), "true") || identical(tolower(value), "false")) {
      value <- identical(tolower(value), "true")
    }
    out[[hit[2]]] <- value
  }
  out
}

#' Parse a BebeLM tool call block
#'
#' The default parser accepts JSON objects such as `{\"name\": \"tool\", \"arguments\": {...}}`,
#' simple `name({...})` calls, and bracketed BebeLM calls such as
#' `[name(key=\"value\")]`. Pass a custom parser to
#' `bebel_agent_run()` for model- or prompt-specific formats.
#'
#' @param content Accumulated content between BebeLM tool-call delimiters.
#' @return A list with `name`, `arguments`, and `raw`.
#' @export
bebel_parse_tool_call <- function(content) {
  raw <- paste(content, collapse = "")
  x <- trimws(raw)
  if (!nzchar(x)) stop("empty tool call", call. = FALSE)
  if (grepl("^\\[.*\\]$", x)) x <- trimws(substr(x, 2L, nchar(x) - 1L))

  if (grepl("^\\s*\\{", x)) {
    obj <- rbebelm_json_parse(x)
    name <- obj$name %||% obj$tool %||% (obj[["function"]] %||% list())$name
    args <- obj$arguments %||% obj$args %||% obj$input %||% list()
    if (is.character(args) && length(args) == 1L && grepl("^\\s*\\{", args)) {
      args <- tryCatch(rbebelm_json_parse(args), error = function(e) args)
    }
    if (is.null(name) || !nzchar(name)) stop("JSON tool call has no name/tool/function.name", call. = FALSE)
    return(list(name = name, arguments = args, raw = raw))
  }

  m <- regexec("^([A-Za-z_][A-Za-z0-9_.-]*)\\s*\\((.*)\\)$", x, perl = TRUE)
  hit <- regmatches(x, m)[[1]]
  if (length(hit)) {
    parsed <- parse_bebel_call_args(hit[3])
    return(list(name = hit[2], arguments = parsed, raw = raw))
  }

  stop("cannot parse tool call; provide a custom parse_tool_call function", call. = FALSE)
}

call_bebel_hook <- function(hooks, name, ...) {
  hook <- hooks[[name]]
  if (is.null(hook)) return(invisible(NULL))
  if (!is.function(hook)) stop("hook '", name, "' must be a function", call. = FALSE)
  hook(...)
  invisible(NULL)
}

invoke_bebel_tool <- function(tool, call, context) {
  fun <- tool$fun
  nms <- names(formals(fun))
  if ("args" %in% nms || "context" %in% nms || "call" %in% nms) {
    args <- list()
    if ("args" %in% nms) args$args <- call$arguments
    if ("context" %in% nms) args$context <- context
    if ("call" %in% nms) args$call <- call
    return(do.call(fun, args))
  }
  if (is.list(call$arguments)) {
    return(do.call(fun, call$arguments))
  }
  fun(call$arguments)
}

format_bebel_tool_result <- function(call, result, error = NULL) {
  rbebelm_json_tool_result(
    call$name,
    is.null(error),
    if (is.null(error) && !is.null(result)) paste(result, collapse = "\n") else NULL,
    if (!is.null(error)) conditionMessage(error) else NULL
  )
}

#' Run a BebeLM agent with R tool dispatch
#'
#' This is an Agent-first orchestration loop. It observes `tool_call_end` events,
#' parses tool calls, invokes matching R tools with private `context`, appends
#' tool results to the agent transcript, and continues generation.
#'
#' @param agent A `BebelAgent` object.
#' @param tools A list of `bebel_tool()` objects or named functions.
#' @param context Private run context passed to tools and hooks but not appended to the model transcript.
#' @param hooks Optional named list of hooks: `turn_start`, `event`, `tool_request`,
#'   `tool_result`, `tool_error`, `turn_end`.
#' @param parse_tool_call Function converting tool-call content to `list(name, arguments, raw)`.
#' @param max_steps Maximum assistant/tool iterations.
#' @param on_event Optional event callback or handler list for model events.
#' @param check_interrupt Check for Ctrl-C during generation.
#' @return A `bebelAgentRun` list with turns, tool calls, and final agent info.
#' @export
bebel_agent_run <- function(
  agent,
  tools = list(),
  context = new.env(parent = emptyenv()),
  hooks = list(),
  parse_tool_call = bebel_parse_tool_call,
  max_steps = 4,
  on_event = NULL,
  check_interrupt = TRUE
) {
  check_bebel_agent(agent)
  tools <- normalize_bebel_tools(tools)
  if (!is.list(hooks)) stop("hooks must be a named list", call. = FALSE)
  if (!is.function(parse_tool_call)) stop("parse_tool_call must be a function", call. = FALSE)

  turns <- list()
  calls <- list()
  for (step in seq_len(max_steps)) {
    tool_blocks <- character()
    user_event <- normalize_bebel_on_event(on_event)
    collector <- bebel_event_handler(
      tool_call_end = function(event) {
        tool_blocks <<- c(tool_blocks, event$content)
        call_bebel_hook(hooks, "event", event = event, context = context, agent = agent, step = step)
        if (!is.null(user_event)) user_event(event)
      },
      default = function(event) {
        call_bebel_hook(hooks, "event", event = event, context = context, agent = agent, step = step)
        if (!is.null(user_event)) user_event(event)
      }
    )

    call_bebel_hook(hooks, "turn_start", context = context, agent = agent, step = step)
    turn <- bebel_assistant_turn(agent, on_event = collector, check_interrupt = check_interrupt)
    turns[[length(turns) + 1L]] <- turn
    call_bebel_hook(hooks, "turn_end", turn = turn, context = context, agent = agent, step = step)

    if (!length(tool_blocks)) break

    for (block in tool_blocks) {
      call <- parse_tool_call(block)
      calls[[length(calls) + 1L]] <- call
      call_bebel_hook(hooks, "tool_request", call = call, context = context, agent = agent, step = step)
      tool <- tools[[call$name]]
      if (is.null(tool)) {
        err <- simpleError(paste0("unknown tool: ", call$name))
        call_bebel_hook(hooks, "tool_error", call = call, error = err, context = context, agent = agent, step = step)
        bebel_append_tool_result(agent, format_bebel_tool_result(call, NULL, err))
        next
      }
      result <- tryCatch(
        invoke_bebel_tool(tool, call, context),
        error = function(e) e
      )
      if (inherits(result, "error")) {
        call_bebel_hook(hooks, "tool_error", call = call, error = result, context = context, agent = agent, step = step)
        bebel_append_tool_result(agent, format_bebel_tool_result(call, NULL, result))
      } else {
        call_bebel_hook(hooks, "tool_result", call = call, result = result, context = context, agent = agent, step = step)
        bebel_append_tool_result(agent, format_bebel_tool_result(call, result))
      }
    }
  }

  structure(
    list(turns = turns, tool_calls = calls, context = context, agent_info = bebel_agent_info(agent)),
    class = "bebelAgentRun"
  )
}

#' @export
print.bebelAgentRun <- function(x, ...) {
  cat("<bebelAgentRun>\n")
  cat("  turns:", length(x$turns), "\n")
  cat("  tool calls:", length(x$tool_calls), "\n")
  if (length(x$turns)) print(x$turns[[length(x$turns)]])
  invisible(x)
}

#' Build a BebeLM generation event handler
#'
#' `bebel_event_handler()` creates a single `on_event` callback from handlers for
#' individual event types. Current event types are returned by
#' `bebel_event_types()`.
#'
#' @param start,thinking_start,thinking_delta,thinking_end,text_start,text_delta,text_end
#'   Optional functions called for the corresponding stream event.
#' @param tool_list_start,tool_list_delta,tool_list_end Optional handlers for
#'   BebeLM tool-list delimiter blocks.
#' @param tool_call_start,tool_call_delta,tool_call_end Optional handlers for
#'   BebeLM tool-call delimiter blocks.
#' @param done Function called for the final done event, or `NULL`.
#' @param default Function called for events without a type-specific handler, or `NULL`.
#' @return A function accepting one generation event list.
#' @export
bebel_event_handler <- function(
  start = NULL,
  thinking_start = NULL,
  thinking_delta = NULL,
  thinking_end = NULL,
  text_start = NULL,
  text_delta = NULL,
  text_end = NULL,
  tool_list_start = NULL,
  tool_list_delta = NULL,
  tool_list_end = NULL,
  tool_call_start = NULL,
  tool_call_delta = NULL,
  tool_call_end = NULL,
  done = NULL,
  default = NULL
) {
  handlers <- list(
    start = start,
    thinking_start = thinking_start,
    thinking_delta = thinking_delta,
    thinking_end = thinking_end,
    text_start = text_start,
    text_delta = text_delta,
    text_end = text_end,
    tool_list_start = tool_list_start,
    tool_list_delta = tool_list_delta,
    tool_list_end = tool_list_end,
    tool_call_start = tool_call_start,
    tool_call_delta = tool_call_delta,
    tool_call_end = tool_call_end,
    done = done,
    default = default
  )
  bad <- !vapply(handlers, function(x) is.null(x) || is.function(x), logical(1))
  if (any(bad)) {
    stop("event handlers must be functions or NULL", call. = FALSE)
  }
  function(event) {
    type <- event$type %||% ""
    handler <- handlers[[type]]
    if (is.null(handler)) {
      handler <- handlers$default
    }
    if (!is.null(handler)) {
      handler(event)
    }
    invisible(NULL)
  }
}

#' Console event handler for generated text and thinking
#'
#' Returns an event handler suitable for `on_event`. Thinking blocks are printed
#' with `<think>` markers, text deltas are printed as they arrive, and done events
#' add a trailing newline.
#'
#' @return A function accepting one generation event list.
#' @export
bebel_console_event <- function() {
  bebel_event_handler(
    thinking_start = function(event) {
      cat("<think>")
      utils::flush.console()
    },
    thinking_delta = function(event) {
      cat(event$delta)
      utils::flush.console()
    },
    thinking_end = function(event) {
      cat("</think>")
      utils::flush.console()
    },
    text_delta = function(event) {
      cat(event$delta)
      utils::flush.console()
    },
    tool_call_start = function(event) {
      cat("<|tool_call_start|>")
      utils::flush.console()
    },
    tool_call_delta = function(event) {
      cat(event$delta)
      utils::flush.console()
    },
    tool_call_end = function(event) {
      cat("<|tool_call_end|>")
      utils::flush.console()
    },
    done = function(event) {
      cat("\n")
      utils::flush.console()
    }
  )
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

normalize_bebel_on_event <- function(on_event) {
  if (is.null(on_event) || is.function(on_event)) {
    return(on_event)
  }
  if (is.list(on_event)) {
    names <- names(on_event)
    if (is.null(names) || any(!nzchar(names))) {
      stop("on_event handler lists must be named", call. = FALSE)
    }
    allowed <- c(bebel_event_types(), "default")
    unknown <- setdiff(names, allowed)
    if (length(unknown)) {
      stop("unknown on_event handler name(s): ", paste(unknown, collapse = ", "), call. = FALSE)
    }
    return(do.call(bebel_event_handler, on_event))
  }
  stop("on_event must be a function, a named list of handlers, or NULL", call. = FALSE)
}

#' Generate a raw continuation from a prompt
#'
#' @param model A `BebelModel` object.
#' @param prompt Prompt text.
#' @param greedy Use deterministic greedy decoding.
#' @param on_event Event callback, named list of event-specific handlers, or
#'   `NULL`. Event types are `bebel_event_types()`. Delta events contain `delta`,
#'   `id`, and `index`; final events contain accumulated `content` or `text`.
#'   Use `bebel_console_event()` for live console output.
#' @param check_interrupt Check for Ctrl-C during prefill and before every decoded token.
#' @param max_gen,max_context,max_think Optional generation limits.
#' @param temperature,top_k,repeat_penalty Optional sampling settings.
#' @return A classed list with generated text, token ids, stop reason, and timing statistics.
#' @export
bebel_generate <- function(
  model,
  prompt,
  greedy = FALSE,
  on_event = bebel_console_event(),
  check_interrupt = TRUE,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
) {
  if (!inherits(model, "BebelModel")) {
    stop("model must be a BebelModel", call. = FALSE)
  }
  on_event <- normalize_bebel_on_event(on_event)
  out <- model$generate(
    prompt = prompt,
    greedy = greedy,
    check_interrupt = check_interrupt,
    on_event = on_event,
    max_gen = max_gen,
    max_context = max_context,
    max_think = max_think,
    temperature = temperature,
    top_k = top_k,
    repeat_penalty = repeat_penalty
  )
  class(out) <- c("bebelGenerateResult", "bebelGeneration", class(out))
  out
}

#' Generate a single ChatML assistant reply
#'
#' @inheritParams bebel_generate
#' @param message User message.
#' @export
bebel_chat <- function(
  model,
  message,
  greedy = FALSE,
  on_event = bebel_console_event(),
  check_interrupt = TRUE,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
) {
  if (!inherits(model, "BebelModel")) {
    stop("model must be a BebelModel", call. = FALSE)
  }
  on_event <- normalize_bebel_on_event(on_event)
  out <- model$chat(
    message = message,
    greedy = greedy,
    check_interrupt = check_interrupt,
    on_event = on_event,
    max_gen = max_gen,
    max_context = max_context,
    max_think = max_think,
    temperature = temperature,
    top_k = top_k,
    repeat_penalty = repeat_penalty
  )
  class(out) <- c("bebelChatResult", "bebelGeneration", class(out))
  out
}


#' Live terminal console for BebeLM chats
#'
#' Start an interactive terminal chat loop. If `x` is a `BebelModel`, a new
#' `BebelAgent` is created. If `x` is a `BebelAgent`, its existing transcript and
#' caches are reused. Type `/quit` or `/exit` to leave the loop.
#'
#' @param x A `BebelModel` or `BebelAgent`.
#' @param prompt Prompt displayed before reading each user message.
#' @param exit_commands Character vector of commands that exit the console.
#' @param on_event Event handler used for assistant output.
#' @param check_interrupt Check for Ctrl-C during generation.
#' @inheritParams bebel_agent
#' @return Invisibly returns the `BebelAgent` used by the console.
#' @export
bebel_live_console <- function(
  x,
  prompt = ">>> ",
  exit_commands = c("/quit", "/exit"),
  on_event = bebel_console_event(),
  check_interrupt = TRUE,
  greedy = FALSE,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
) {
  if (inherits(x, "BebelModel")) {
    x <- bebel_agent(
      x,
      greedy = greedy,
      max_gen = max_gen,
      max_context = max_context,
      max_think = max_think,
      temperature = temperature,
      top_k = top_k,
      repeat_penalty = repeat_penalty
    )
  } else {
    check_bebel_agent(x)
  }
  if (!interactive()) {
    warning("bebel_live_console() is intended for interactive R sessions", call. = FALSE)
  }
  cat("\u2554\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2557\n")
  cat("\u2551  Entering BebeLM live console.                     \u2551\n")
  cat("\u2551  Type /quit or /exit to return to R.               \u2551\n")
  cat("\u255a\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u255d\n")
  repeat {
    message <- readline(prompt)
    if (!nzchar(message)) next
    if (message %in% exit_commands) break
    bebel_append_user(x, message)
    bebel_assistant_turn(x, on_event = on_event, check_interrupt = check_interrupt)
  }
  invisible(x)
}

#' @export
print.BebelModel <- function(x, ...) {
  info <- x$info()
  cat("<BebelModel>\n")
  cat("  path:", info$path, "\n")
  cat("  backend:", info$backend, "\n")
  invisible(x)
}

#' @export
print.BebelAgent <- function(x, ...) {
  info <- x$info()
  cat("<BebelAgent>\n")
  cat("  model:", info$model_path, "\n")
  cat("  history tokens:", info$history_tokens, "\n")
  cat("  processed tokens:", info$processed_tokens, "\n")
  cat("  backend:", info$backend, "\n")
  invisible(x)
}

#' Print a BebeLM generation result
#'
#' @param x A result returned by [bebel_generate()] or [bebel_chat()].
#' @param ... Unused.
#' @return Invisibly returns `x`.
#' @export
print.bebelGeneration <- function(x, ...) {
  kind <- if (inherits(x, "bebelAssistantTurnResult")) {
    "BebeLM assistant turn"
  } else if (inherits(x, "bebelAgentGenerateResult")) {
    "BebeLM agent generation"
  } else if (inherits(x, "bebelChatResult")) {
    "BebeLM chat result"
  } else {
    "BebeLM generation result"
  }
  cat("<", kind, ">\n", sep = "")
  cat("  stop:", x$stop, "\n")
  cat("  tokens:", x$generated_tokens, "generated;", x$prompt_tokens, "prompt\n")
  cat("  prefill:", sprintf("%.1f tok/s", x$prefill_tps), "\n")
  cat("  decode:", sprintf("%.2f tok/s", x$decode_tps), "\n")
  if (nzchar(x$text)) {
    cat("  text:\n")
    cat(x$text, "\n", sep = "")
  }
  invisible(x)
}
