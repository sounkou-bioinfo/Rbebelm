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
  cat("  mode: ", x$dispatch_mode, "\n", sep = "")
  cat("  requested: ", x$requested_backend, "\n", sep = "")
  cat("  selected: ", x$selected_backend, "\n", sep = "")
  cat("  loaded: ", format_bebel_yes_no(x$backend_loaded), "\n", sep = "")
  cat("  installed: ", x$installed_backends, "\n", sep = "")
  cat("  supported: ", x$supported_backends, "\n", sep = "")
  invisible(x)
}

#' @export
print.rbebelmCpuidInfo <- function(x, ...) {
  cat("<Rbebelm CPU features>\n")
  cat("  x86_64-v3: ", format_bebel_yes_no(x$cpu_x86_64_v3), "\n", sep = "")
  cat("  x86_64-v4: ", format_bebel_yes_no(x$cpu_x86_64_v4), "\n", sep = "")
  cat("  NEON: ", format_bebel_yes_no(x$cpu_neon), "\n", sep = "")
  cat("  ARM dotprod: ", format_bebel_yes_no(x$cpu_dotprod), "\n", sep = "")
  cat("  wasm simd128: ", format_bebel_yes_no(x$cpu_wasm_simd128), "\n", sep = "")
  invisible(x)
}

#' @export
print.rbebelmBackendFeatures <- function(x, ...) {
  cat("<Rbebelm backend features>\n")
  cat("  backend: ", x$backend, "\n", sep = "")
  cat("  target: ", paste0(x$target_arch, "-", x$target_os), "\n", sep = "")
  cat("  Rust crate: ", paste0(x$rust_package, " ", x$rust_package_version), "\n", sep = "")
  cat("  native SIMD feature: ", format_bebel_yes_no(x$native_simd_feature), "\n", sep = "")
  cat("  compiled features:\n")
  cat("    AVX2: ", format_bebel_yes_no(x$compiled_avx2), "\n", sep = "")
  cat("    AVX-512F: ", format_bebel_yes_no(x$compiled_avx512f), "\n", sep = "")
  cat("    NEON: ", format_bebel_yes_no(x$compiled_neon), "\n", sep = "")
  cat("    ARM dotprod: ", format_bebel_yes_no(x$compiled_dotprod), "\n", sep = "")
  cat("    wasm simd128: ", format_bebel_yes_no(x$compiled_wasm_simd128), "\n", sep = "")
  invisible(x)
}

bebel_numeric_or_null <- function(x) {
  if (is.null(x)) NULL else as.numeric(x)
}

#' Load a BebeLM GGUF model
#'
#' @param path Path to the GGUF weights file.
#' @param num_threads Optional Rayon global thread-pool size. This can only be set once per R process.
#' @return A `BebelModel` object.
#' @export
bebel_model_load <- function(path, num_threads = NULL) {
  BebelModel$load(path, num_threads = bebel_numeric_or_null(num_threads))
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
    max_gen = bebel_numeric_or_null(max_gen),
    max_context = bebel_numeric_or_null(max_context),
    max_think = bebel_numeric_or_null(max_think),
    temperature = bebel_numeric_or_null(temperature),
    top_k = bebel_numeric_or_null(top_k),
    repeat_penalty = bebel_numeric_or_null(repeat_penalty)
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
    max_gen = bebel_numeric_or_null(max_gen),
    max_context = bebel_numeric_or_null(max_context),
    max_think = bebel_numeric_or_null(max_think),
    temperature = bebel_numeric_or_null(temperature),
    top_k = bebel_numeric_or_null(top_k),
    repeat_penalty = bebel_numeric_or_null(repeat_penalty)
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

#' Append an upstream BebeLM system turn to an agent transcript
#'
#' Delegates ChatML system-turn rendering to upstream BebeLM. When `tools` are
#' supplied, their schemas are rendered in upstream's `List of tools: [...]`
#' system-block preamble before `message`.
#'
#' @param agent A `BebelAgent` object.
#' @param message System instruction text.
#' @param tools Optional list of `bebel_tool()` objects or named functions to advertise.
#' @return Invisibly returns `agent`.
#' @export
bebel_append_system <- function(agent, message, tools = NULL) {
  check_bebel_agent(agent)
  tools <- normalize_bebel_tools(tools)
  if (length(tools)) {
    schemas <- vapply(tools, bebel_tool_schema_json, character(1))
    agent$append_system_with_tools(message, names(tools), schemas)
  } else {
    agent$append_system(message)
  }
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

#' Open an assistant turn and stop when a tool call closes
#'
#' This low-level variant mirrors upstream BebeLM's tool driver stop semantics:
#' generation stops with `stop == "tool_call"` after `<|tool_call_end|>` so the
#' caller can execute the requested tool(s) and append one tool-result turn.
#' Most users should prefer [bebel_agent_run()].
#'
#' @inheritParams bebel_assistant_turn
#' @return A `bebelAssistantTurnResult` list.
#' @export
bebel_assistant_turn_tool_stop <- function(agent, on_event = bebel_console_event(), check_interrupt = TRUE) {
  check_bebel_agent(agent)
  on_event <- normalize_bebel_on_event(on_event)
  out <- agent$assistant_turn_tool_stop(check_interrupt = check_interrupt, on_event = on_event)
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
  cat("<bebelTool> ", x$name, "\n", sep = "")
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

bebel_json_read_opts <- function() {
  yyjsonr::opts_read_json(
    obj_of_arrs_to_df = FALSE,
    arr_of_objs_to_df = FALSE,
    arr_of_arrs_to_matrix = FALSE
  )
}

bebel_json_write_opts <- function(auto_unbox = TRUE) {
  yyjsonr::opts_write_json(auto_unbox = auto_unbox, pretty = FALSE, null = "null")
}

bebel_json_read <- function(x) {
  yyjsonr::read_json_str(x, opts = bebel_json_read_opts())
}

bebel_json_write <- function(x, auto_unbox = TRUE) {
  yyjsonr::write_json_str(x, opts = bebel_json_write_opts(auto_unbox = auto_unbox))
}

bebel_json_string_array <- function(x) {
  as.list(as.character(unlist(x %||% list(), use.names = FALSE)))
}

normalize_bebel_tool_schema_json <- function(schema) {
  if (is.null(schema)) schema <- list()
  if (!is.list(schema)) stop("tool schema must be a list or JSON string", call. = FALSE)
  if (is.null(schema$type)) schema$type <- "object"
  if (is.null(schema$properties)) schema$properties <- stats::setNames(list(), character())
  if (is.null(schema$required)) schema$required <- list()
  schema$required <- bebel_json_string_array(schema$required)
  schema
}

#' Render a BebeLM tool schema
#'
#' Converts an R [bebel_tool()] declaration into BebeLM's JSON tool schema string
#' for the system `List of tools: [...]` preamble using `yyjsonr`. This is
#' normally called by [bebel_append_system()] when `tools` are supplied.
#'
#' @param tool A `bebelTool` object created by [bebel_tool()].
#' @return A character scalar containing the rendered tool schema.
#' @export
bebel_tool_schema_json <- function(tool) {
  schema <- tool$schema
  if (is.character(schema) && length(schema) == 1L && nzchar(schema)) return(schema)

  bebel_json_write(list(
    name = as.character(tool$name),
    description = as.character(tool$description %||% tool$name),
    parameters = normalize_bebel_tool_schema_json(schema)
  ))
}


coerce_bebel_tool_value <- function(value) {
  if (!is.character(value) || length(value) != 1L) return(value)
  x <- trimws(value)
  if (identical(x, "True") || identical(x, "true")) return(TRUE)
  if (identical(x, "False") || identical(x, "false")) return(FALSE)
  if (grepl("^-?[0-9]+$", x)) return(as.integer(x))
  if (grepl("^-?[0-9]+\\.[0-9]+$", x)) return(as.numeric(x))
  value
}

normalize_upstream_tool_call <- function(call) {
  if (is.list(call$arguments)) {
    call$arguments <- lapply(call$arguments, coerce_bebel_tool_value)
  }
  call
}

parse_json_tool_call <- function(x, raw) {
  obj <- bebel_json_read(x)
  name <- obj$name %||% obj$tool %||% (obj[["function"]] %||% list())$name
  args <- obj$arguments %||% obj$args %||% obj$input %||% list()
  if (is.character(args) && length(args) == 1L && grepl("^\\s*\\{", args)) {
    args <- tryCatch(bebel_json_read(args), error = function(e) args)
  }
  if (is.null(name) || !nzchar(name)) stop("JSON tool call has no name/tool/function.name", call. = FALSE)
  list(name = name, arguments = args, raw = raw)
}

#' Parse BebeLM tool calls
#'
#' Delegates Pythonic BebeLM tool-call parsing (`[name(arg='value')]`, including
#' multiple calls) to upstream BebeLM. JSON call objects and legacy `name({...})`
#' calls are parsed with imported package `yyjsonr`.
#'
#' @param content Accumulated content between BebeLM tool-call delimiters.
#' @return A list of calls, each with `name`, `arguments`, and `raw`.
#' @export
bebel_parse_tool_calls <- function(content) {
  raw <- paste(content, collapse = "")
  x <- trimws(raw)
  if (!nzchar(x)) stop("empty tool call", call. = FALSE)

  if (grepl("^\\s*\\{", x)) return(list(parse_json_tool_call(x, raw)))

  m_json_arg <- regexec("^([A-Za-z_][A-Za-z0-9_.-]*)\\s*\\((\\s*\\{.*\\}\\s*)\\)$", x, perl = TRUE)
  hit_json_arg <- regmatches(x, m_json_arg)[[1]]
  if (length(hit_json_arg)) {
    return(list(list(name = hit_json_arg[2], arguments = bebel_json_read(hit_json_arg[3]), raw = raw)))
  }

  calls <- rbebelm_parse_tool_calls(x)
  calls <- lapply(calls, normalize_upstream_tool_call)
  if (!length(calls)) stop("cannot parse tool call; provide a custom parse_tool_call function", call. = FALSE)
  calls
}

#' Parse a single BebeLM tool call block
#'
#' This compatibility wrapper returns the first call from [bebel_parse_tool_calls()].
#' Prefer [bebel_parse_tool_calls()] when multiple calls may be present.
#'
#' @inheritParams bebel_parse_tool_calls
#' @return A list with `name`, `arguments`, and `raw`.
#' @export
bebel_parse_tool_call <- function(content) {
  calls <- bebel_parse_tool_calls(content)
  calls[[1L]]
}

format_bebel_tool_result <- function(call, result, error = NULL) {
  if (!is.null(error)) return(paste0("Error: ", conditionMessage(error)))
  if (is.null(result)) return("")
  if (is.list(result) && !is.null(result$text)) return(as.character(result$text)[[1L]])
  paste(result, collapse = "\n")
}

normalize_parsed_bebel_calls <- function(parsed) {
  if (is.list(parsed) && !is.null(parsed$name)) return(list(parsed))
  if (is.list(parsed) && all(vapply(parsed, function(x) is.list(x) && !is.null(x$name), logical(1)))) return(parsed)
  stop("parse_tool_call must return a call or a list of calls", call. = FALSE)
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
#' @param parse_tool_call Function converting tool-call content to either one `list(name, arguments, raw)` or a list of such calls.
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
  parse_tool_call = bebel_parse_tool_calls,
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
    if (length(tools)) {
      turn <- bebel_assistant_turn_tool_stop(agent, on_event = collector, check_interrupt = check_interrupt)
    } else {
      turn <- bebel_assistant_turn(agent, on_event = collector, check_interrupt = check_interrupt)
    }
    turns[[length(turns) + 1L]] <- turn
    call_bebel_hook(hooks, "turn_end", turn = turn, context = context, agent = agent, step = step)

    if (!length(tool_blocks)) break

    for (block in tool_blocks) {
      call <- tryCatch(
        parse_tool_call(block),
        error = function(e) {
          preview <- block
          if (nchar(preview) > 500L) preview <- paste0(substr(preview, 1L, 500L), "...")
          simpleError(paste0("cannot parse tool call ", sQuote(preview), ": ", conditionMessage(e)))
        }
      )
      if (inherits(call, "error")) {
        err <- call
        call <- list(name = "parse_tool_call", arguments = list(raw = block), raw = block)
        calls[[length(calls) + 1L]] <- call
        call_bebel_hook(hooks, "tool_error", call = call, error = err, context = context, agent = agent, step = step)
        bebel_append_tool_result(agent, format_bebel_tool_result(call, NULL, err))
        next
      }
      parsed_calls <- normalize_parsed_bebel_calls(call)
      block_results <- character()
      for (call in parsed_calls) {
        calls[[length(calls) + 1L]] <- call
        call_bebel_hook(hooks, "tool_request", call = call, context = context, agent = agent, step = step)
        tool <- tools[[call$name]]
        if (is.null(tool)) {
          err <- simpleError(paste0("unknown tool: ", call$name))
          call_bebel_hook(hooks, "tool_error", call = call, error = err, context = context, agent = agent, step = step)
          block_results <- c(block_results, format_bebel_tool_result(call, NULL, err))
          next
        }
        result <- tryCatch(
          invoke_bebel_tool(tool, call, context),
          error = function(e) e
        )
        if (inherits(result, "error")) {
          call_bebel_hook(hooks, "tool_error", call = call, error = result, context = context, agent = agent, step = step)
          block_results <- c(block_results, format_bebel_tool_result(call, NULL, result))
        } else {
          call_bebel_hook(hooks, "tool_result", call = call, result = result, context = context, agent = agent, step = step)
          block_results <- c(block_results, format_bebel_tool_result(call, result))
        }
      }
      bebel_append_tool_result(agent, paste(block_results, collapse = "\n"))
    }
  }

  structure(
    list(turns = turns, tool_calls = calls, context = context, backend_info = bebel_agent_info(agent)),
    class = "bebelAgentRun"
  )
}

#' @export
print.bebelAgentRun <- function(x, ...) {
  cat("<bebelAgentRun>\n")
  cat("  turns: ", length(x$turns), "\n", sep = "")
  cat("  tool calls: ", length(x$tool_calls), "\n", sep = "")
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
    max_gen = bebel_numeric_or_null(max_gen),
    max_context = bebel_numeric_or_null(max_context),
    max_think = bebel_numeric_or_null(max_think),
    temperature = bebel_numeric_or_null(temperature),
    top_k = bebel_numeric_or_null(top_k),
    repeat_penalty = bebel_numeric_or_null(repeat_penalty)
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
    max_gen = bebel_numeric_or_null(max_gen),
    max_context = bebel_numeric_or_null(max_context),
    max_think = bebel_numeric_or_null(max_think),
    temperature = bebel_numeric_or_null(temperature),
    top_k = bebel_numeric_or_null(top_k),
    repeat_penalty = bebel_numeric_or_null(repeat_penalty)
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
  cat("  path: ", info$path, "\n", sep = "")
  cat("  backend: ", info$backend, "\n", sep = "")
  invisible(x)
}

#' @export
print.BebelAgent <- function(x, ...) {
  info <- x$info()
  cat("<BebelAgent>\n")
  cat("  model: ", info$model_path, "\n", sep = "")
  cat("  history tokens: ", info$history_tokens, "\n", sep = "")
  cat("  processed tokens: ", info$processed_tokens, "\n", sep = "")
  cat("  backend: ", info$backend, "\n", sep = "")
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
  cat("  stop: ", x$stop, "\n", sep = "")
  cat("  tokens: ", x$generated_tokens, " generated; ", x$prompt_tokens, " prompt\n", sep = "")
  cat("  prefill: ", sprintf("%.1f tok/s", x$prefill_tps), "\n", sep = "")
  cat("  decode: ", sprintf("%.2f tok/s", x$decode_tps), "\n", sep = "")
  if (nzchar(x$text)) {
    cat("  text:\n")
    cat(x$text, "\n", sep = "")
  }
  invisible(x)
}
