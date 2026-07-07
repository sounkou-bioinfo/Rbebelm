`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Select the Rbebelm native backend
#'
#' Must be called before loading a model or querying backend features.
#'
#' @param backend One of `"auto"`, `"scalar"`, `"avx2"`, `"avx512"`, `"neon"`, or `"wasm_simd128"`.
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
  cat("  model storage: ", x$model_storage, "\n", sep = "")
  invisible(x)
}

#' Load a BebeLM GGUF model
#'
#' @param path Path to the GGUF weights file.
#' @param num_threads Optional Rayon global thread-pool size. This can only be set once per R process.
#' @return A `BebelModel` object.
#' @export
bebel_model_load <- function(path, num_threads = NULL) {
  options <- BebelModelLoadOptions(
    path = path,
    num_threads = if (is.null(num_threads)) NULL else as.numeric(num_threads)
  )
  BebelModel$load(
    S7::prop(options, "path"),
    num_threads = S7::prop(options, "num_threads")
  )
}

#' Tokenize text with a BebeLM model tokenizer
#'
#' @param model A `BebelModel` object.
#' @param text Text to encode.
#' @param add_bos Whether to prepend the BOS token.
#' @return Integer token ids.
#' @export
bebel_tokenize <- function(model, text, add_bos = TRUE) {
  model <- S7::prop(BebelModelRef(value = list(model)), "value")[[1L]]
  text <- S7::prop(BebelScalarText(value = text), "value")
  options <- BebelEmbeddingOptions(
    add_bos = isTRUE(add_bos),
    normalize = TRUE,
    pooling = "mean",
    token_batch_size = 1L,
    sequence_batch_size = 1L,
    check_interrupt = FALSE
  )
  model$encode(text, add_bos = S7::prop(options, "add_bos"))
}

#' Decode BebeLM token ids
#'
#' @param model A `BebelModel` object.
#' @param ids Integer token ids.
#' @return Decoded text.
#' @export
bebel_detokenize <- function(model, ids) {
  model <- S7::prop(BebelModelRef(value = list(model)), "value")[[1L]]
  model$decode(as.integer(ids))
}

#' Embed text with pooled BebeLM hidden states
#'
#' @param model A `BebelModel` object.
#' @param text Character vector.
#' @param add_bos Whether to prepend the BOS token before embedding.
#' @param normalize L2-normalize each embedding row.
#' @param pooling Hidden-state pooling strategy: `mean` or `last`.
#' @param token_batch_size Number of tokens per Rust batched prefill/matmul call.
#' @param sequence_batch_size Number of texts per independent-sequence embedding
#'   batch.
#' @param check_interrupt Whether long embedding runs should poll R interrupts
#'   between texts and token batches.
#' @return A numeric matrix with one row per input text.
#' @export
bebel_embed <- function(model,
                        text,
                        add_bos = TRUE,
                        normalize = TRUE,
                        pooling = c("mean", "last"),
                        token_batch_size = 512L,
                        sequence_batch_size = 64L,
                        check_interrupt = TRUE) {
  model <- S7::prop(BebelModelRef(value = list(model)), "value")[[1L]]
  if (!is.character(text) || anyNA(text)) {
    stop("`text` must be a character vector without NA.", call. = FALSE)
  }
  options <- BebelEmbeddingOptions(
    add_bos = isTRUE(add_bos),
    normalize = isTRUE(normalize),
    pooling = match.arg(pooling),
    token_batch_size = token_batch_size,
    sequence_batch_size = sequence_batch_size,
    check_interrupt = isTRUE(check_interrupt)
  )
  out <- model$embed_batch(
    text,
    add_bos = S7::prop(options, "add_bos"),
    normalize = S7::prop(options, "normalize"),
    pooling = S7::prop(options, "pooling"),
    token_batch_size = as.numeric(S7::prop(options, "token_batch_size")),
    sequence_batch_size = as.numeric(S7::prop(options, "sequence_batch_size")),
    check_interrupt = S7::prop(options, "check_interrupt")
  )
  rownames(out) <- names(text)
  out
}

#' Create a persistent BebeLM agent
#'
#' A `BebelAgent` owns an independent token transcript and decode cache while
#' sharing the loaded model weights through Rust `Arc<Model>`.
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
  model <- S7::prop(BebelModelRef(value = list(model)), "value")[[1L]]
  options <- BebelAgentOptions(
    greedy = isTRUE(greedy),
    max_gen = if (is.null(max_gen)) NULL else as.numeric(max_gen),
    max_context = if (is.null(max_context)) NULL else as.numeric(max_context),
    max_think = if (is.null(max_think)) NULL else as.numeric(max_think),
    temperature = if (is.null(temperature)) NULL else as.numeric(temperature),
    top_k = if (is.null(top_k)) NULL else as.numeric(top_k),
    repeat_penalty = if (is.null(repeat_penalty)) NULL else as.numeric(repeat_penalty)
  )
  BebelAgent$new(
    model = model,
    greedy = S7::prop(options, "greedy"),
    max_gen = S7::prop(options, "max_gen"),
    max_context = S7::prop(options, "max_context"),
    max_think = S7::prop(options, "max_think"),
    temperature = S7::prop(options, "temperature"),
    top_k = S7::prop(options, "top_k"),
    repeat_penalty = S7::prop(options, "repeat_penalty")
  )
}

#' Inspect a BebeLM agent
#'
#' @param agent A `BebelAgent` object.
#' @return Named list of state and configuration.
#' @export
bebel_agent_info <- function(agent) {
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
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
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  options <- BebelAgentConfigureOptions(
    greedy = if (is.null(greedy)) NULL else isTRUE(greedy),
    max_gen = if (is.null(max_gen)) NULL else as.numeric(max_gen),
    max_context = if (is.null(max_context)) NULL else as.numeric(max_context),
    max_think = if (is.null(max_think)) NULL else as.numeric(max_think),
    temperature = if (is.null(temperature)) NULL else as.numeric(temperature),
    top_k = if (is.null(top_k)) NULL else as.numeric(top_k),
    repeat_penalty = if (is.null(repeat_penalty)) NULL else as.numeric(repeat_penalty)
  )
  agent$configure(
    greedy = S7::prop(options, "greedy"),
    max_gen = S7::prop(options, "max_gen"),
    max_context = S7::prop(options, "max_context"),
    max_think = S7::prop(options, "max_think"),
    temperature = S7::prop(options, "temperature"),
    top_k = S7::prop(options, "top_k"),
    repeat_penalty = S7::prop(options, "repeat_penalty")
  )
}

#' Append raw text to a BebeLM agent transcript
#'
#' @param agent A `BebelAgent` object.
#' @param text Raw text to append.
#' @return Invisibly returns `agent`.
#' @export
bebel_append <- function(agent, text) {
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  text <- S7::prop(BebelScalarText(value = text), "value")
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
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  message <- S7::prop(BebelScalarText(value = message), "value")
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
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  message <- S7::prop(BebelScalarText(value = message), "value")
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
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  agent$append_tokens(as.integer(ids))
  invisible(agent)
}

#' Append a ChatML tool result turn to a BebeLM agent transcript
#'
#' @param agent A `BebelAgent` object.
#' @param content Tool result content to append.
#' @return Invisibly returns `agent`.
#' @export
bebel_append_tool_result <- function(agent, content) {
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  agent$append_tool_result(as.character(content)[1])
  invisible(agent)
}

#' Generate a raw continuation from a BebeLM agent transcript
#'
#' @param agent A `BebelAgent` object.
#' @inheritParams bebel_generate
#' @param check_interrupt Check for R interrupts during synchronous agent generation.
#' @return A classed generation result.
#' @export
bebel_agent_generate <- function(agent, on_event = NULL, check_interrupt = TRUE) {
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  on_event <- normalize_bebel_on_event(on_event)
  options <- BebelAgentRunOptions(max_steps = 1, check_interrupt = isTRUE(check_interrupt))
  out <- agent$generate(check_interrupt = S7::prop(options, "check_interrupt"), on_event = on_event)
  class(out) <- c("bebelAgentGenerateResult", "bebelGeneration", class(out))
  out
}

#' Generate and close an assistant ChatML turn from a BebeLM agent
#'
#' @inheritParams bebel_agent_generate
#' @return A classed generation result.
#' @export
bebel_assistant_turn <- function(agent, on_event = NULL, check_interrupt = TRUE) {
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  on_event <- normalize_bebel_on_event(on_event)
  options <- BebelAgentRunOptions(max_steps = 1, check_interrupt = isTRUE(check_interrupt))
  out <- agent$assistant_turn(check_interrupt = S7::prop(options, "check_interrupt"), on_event = on_event)
  class(out) <- c("bebelAssistantTurnResult", "bebelGeneration", class(out))
  out
}

#' Open an assistant turn and stop when a tool call closes
#'
#' This low-level variant mirrors upstream BebeLM's tool driver stop semantics:
#' generation stops with `stop == "tool_call"` after `<|tool_call_end|>` so the
#' caller can execute the requested tool and append one tool-result turn.
#'
#' @inheritParams bebel_assistant_turn
#' @return A `bebelAssistantTurnResult` list.
#' @export
bebel_assistant_turn_tool_stop <- function(agent, on_event = NULL, check_interrupt = TRUE) {
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  on_event <- normalize_bebel_on_event(on_event)
  options <- BebelAgentRunOptions(max_steps = 1, check_interrupt = isTRUE(check_interrupt))
  out <- agent$assistant_turn_tool_stop(check_interrupt = S7::prop(options, "check_interrupt"), on_event = on_event)
  class(out) <- c("bebelAssistantTurnResult", "bebelGeneration", class(out))
  out
}

#' Clear a BebeLM agent transcript and caches
#'
#' Clears the conversation state while keeping the loaded model weights and the
#' agent's generation configuration.
#'
#' @param agent A `BebelAgent` object.
#' @return Updated agent info.
#' @export
bebel_clear <- function(agent) {
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  agent$clear()
}

#' Return a BebeLM agent token transcript
#'
#' @param agent A `BebelAgent` object.
#' @return Integer token ids.
#' @export
bebel_history <- function(agent) {
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  agent$history()
}

#' Decode a BebeLM agent transcript
#'
#' @param agent A `BebelAgent` object.
#' @return Transcript text.
#' @export
bebel_transcript <- function(agent) {
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  agent$transcript()
}

#' Define a BebeLM R tool
#'
#' @param name Tool name exposed to the tool dispatcher.
#' @param fun Function to run. It is called as `fun(args = ..., context = ..., call = ...)`
#'   when it accepts those names, otherwise with progressively simpler fallbacks.
#' @param description Optional human-readable description.
#' @param schema Optional JSON-schema-like list or JSON string.
#' @return A `BebelToolSpec` object.
#' @export
bebel_tool <- function(name, fun, description = NULL, schema = NULL) {
  BebelToolSpec(name = name, fun = fun, description = description, schema = schema)
}

#' @export
print.BebelToolSpec <- function(x, ...) {
  cat("<BebelToolSpec> ", S7::prop(x, "name"), "\n", sep = "")
  description <- S7::prop(x, "description")
  if (!is.null(description)) cat("  ", description, "\n", sep = "")
  invisible(x)
}

#' @export
`print.Rbebelm::BebelToolSpec` <- print.BebelToolSpec

normalize_bebel_tools <- function(tools) {
  if (is.null(tools)) return(list())
  if (S7::S7_inherits(tools, BebelToolSpec)) tools <- list(tools)
  if (!is.list(tools)) stop("`tools` must be a list of BebelToolSpec objects or functions.", call. = FALSE)

  out <- list()
  nms <- names(tools)
  for (i in seq_along(tools)) {
    tool <- tools[[i]]
    if (S7::S7_inherits(tool, BebelToolSpec)) {
      name <- S7::prop(tool, "name")
    } else if (is.function(tool)) {
      name <- if (is.null(nms)) "" else nms[[i]]
      if (is.null(name) || !nzchar(name)) stop("function tools must be named.", call. = FALSE)
      tool <- bebel_tool(name, tool)
    } else {
      stop("`tools` must contain BebelToolSpec objects or functions.", call. = FALSE)
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
  if (!is.list(schema)) stop("tool schema must be a list or JSON string.", call. = FALSE)
  if (is.null(schema$type)) schema$type <- "object"
  if (is.null(schema$properties)) schema$properties <- stats::setNames(list(), character())
  if (is.null(schema$required)) schema$required <- list()
  schema$required <- bebel_json_string_array(schema$required)
  schema
}

#' Render a BebeLM tool schema
#'
#' Converts an R [bebel_tool()] declaration into BebeLM's JSON tool schema string
#' for the system `List of tools: [...]` preamble.
#'
#' @param tool A `BebelToolSpec` object created by [bebel_tool()].
#' @return A character scalar containing the rendered tool schema.
#' @export
bebel_tool_schema_json <- function(tool) {
  tool <- S7::prop(BebelToolRef(value = list(tool)), "value")[[1L]]
  schema <- S7::prop(tool, "schema")
  if (is.character(schema) && length(schema) == 1L && nzchar(schema)) return(schema)

  name <- S7::prop(tool, "name")
  description <- S7::prop(tool, "description") %||% name
  bebel_json_write(list(
    name = as.character(name),
    description = as.character(description),
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
  if (is.null(name) || !nzchar(name)) stop("JSON tool call has no name/tool/function.name.", call. = FALSE)
  list(name = name, arguments = args, raw = raw)
}

#' Parse BebeLM tool calls
#'
#' Delegates Pythonic BebeLM tool-call parsing (`[name(arg='value')]`) to
#' upstream BebeLM. JSON call objects and legacy `name({...})` calls are parsed
#' with imported package `yyjsonr`.
#'
#' @param content Accumulated content between BebeLM tool-call delimiters.
#' @return A list of calls, each with `name`, `arguments`, and `raw`.
#' @export
bebel_parse_tool_calls <- function(content) {
  raw <- paste(content, collapse = "")
  x <- trimws(raw)
  if (!nzchar(x)) stop("empty tool call.", call. = FALSE)

  if (grepl("^\\s*\\{", x)) return(list(parse_json_tool_call(x, raw)))

  m_json_arg <- regexec("^([A-Za-z_][A-Za-z0-9_.-]*)\\s*\\((\\s*\\{.*\\}\\s*)\\)$", x, perl = TRUE)
  hit_json_arg <- regmatches(x, m_json_arg)[[1]]
  if (length(hit_json_arg)) {
    return(list(list(name = hit_json_arg[2], arguments = bebel_json_read(hit_json_arg[3]), raw = raw)))
  }

  calls <- rbebelm_parse_tool_calls(x)
  calls <- lapply(calls, normalize_upstream_tool_call)
  if (!length(calls)) stop("cannot parse tool call; provide a custom parse_tool_call function.", call. = FALSE)
  calls
}

#' Parse a single BebeLM tool call block
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
  stop("parse_tool_call must return a call or a list of calls.", call. = FALSE)
}

call_bebel_hook <- function(hooks, name, ...) {
  hook <- hooks[[name]]
  if (is.null(hook)) return(invisible(NULL))
  if (!is.function(hook)) stop("hook '", name, "' must be a function.", call. = FALSE)
  hook(...)
  invisible(NULL)
}

invoke_bebel_tool <- function(tool, call, context) {
  tool <- S7::prop(BebelToolRef(value = list(tool)), "value")[[1L]]
  fun <- S7::prop(tool, "fun")
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
#' @param on_event Optional event handler function or named handler list for model events.
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
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  tools <- normalize_bebel_tools(tools)
  options <- BebelAgentRunOptions(max_steps = as.numeric(max_steps), check_interrupt = isTRUE(check_interrupt))
  max_steps <- S7::prop(options, "max_steps")
  check_interrupt <- S7::prop(options, "check_interrupt")
  if (!is.list(hooks)) stop("`hooks` must be a named list.", call. = FALSE)
  if (!is.function(parse_tool_call)) stop("`parse_tool_call` must be a function.", call. = FALSE)

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
#' `bebel_event_handler()` creates a single `on_event` handler function from handlers for
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
    stop("event handlers must be functions or NULL.", call. = FALSE)
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

normalize_bebel_on_event <- function(on_event) {
  if (is.null(on_event) || is.function(on_event)) {
    return(on_event)
  }
  if (is.list(on_event)) {
    names <- names(on_event)
    if (is.null(names) || any(!nzchar(names))) {
      stop("on_event handler lists must be named.", call. = FALSE)
    }
    allowed <- c(bebel_event_types(), "default")
    unknown <- setdiff(names, allowed)
    if (length(unknown)) {
      stop("unknown on_event handler name(s): ", paste(unknown, collapse = ", "), call. = FALSE)
    }
    return(do.call(bebel_event_handler, on_event))
  }
  stop("on_event must be a function, a named list of handlers, or NULL.", call. = FALSE)
}

#' Generate a raw continuation from a prompt
#'
#' @param model A `BebelModel` object.
#' @param prompt Prompt text.
#' @param greedy Use deterministic greedy decoding.
#' @param on_event Event handler function, named list of event-specific handlers, or
#'   `NULL`. Event types are `bebel_event_types()`. Delta events contain `delta`,
#'   `id`, and `index`; final events contain accumulated `content` or `text`.
#' @param check_interrupt Cancel the underlying async job when the R wait is interrupted.
#' @param max_gen,max_context,max_think Optional generation limits.
#' @param temperature,top_k,repeat_penalty Optional sampling settings.
#' @param poll_interval Seconds to sleep between async-job polls.
#' @return A classed list with generated text, token ids, stop reason, and timing statistics.
#' @export
bebel_generate <- function(
  model,
  prompt,
  greedy = FALSE,
  on_event = NULL,
  check_interrupt = TRUE,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL,
  poll_interval = 0.005
) {
  prompt <- S7::prop(BebelScalarText(value = prompt), "value")
  options <- BebelGenerationOptions(
    greedy = isTRUE(greedy),
    check_interrupt = isTRUE(check_interrupt),
    max_gen = if (is.null(max_gen)) NULL else as.numeric(max_gen),
    max_context = if (is.null(max_context)) NULL else as.numeric(max_context),
    max_think = if (is.null(max_think)) NULL else as.numeric(max_think),
    temperature = if (is.null(temperature)) NULL else as.numeric(temperature),
    top_k = if (is.null(top_k)) NULL else as.numeric(top_k),
    repeat_penalty = if (is.null(repeat_penalty)) NULL else as.numeric(repeat_penalty)
  )
  on_event <- normalize_bebel_on_event(on_event)
  job <- bebel_generate_async(
    model = model,
    prompt = prompt,
    greedy = S7::prop(options, "greedy"),
    max_gen = S7::prop(options, "max_gen"),
    max_context = S7::prop(options, "max_context"),
    max_think = S7::prop(options, "max_think"),
    temperature = S7::prop(options, "temperature"),
    top_k = S7::prop(options, "top_k"),
    repeat_penalty = S7::prop(options, "repeat_penalty")
  )
  bebel_async_wait(
    job,
    on_event = on_event,
    poll_interval = poll_interval,
    cancel_on_interrupt = S7::prop(options, "check_interrupt")
  )
}

#' Generate a single ChatML assistant reply
#'
#' @inheritParams bebel_generate
#' @param message User message.
#' @return A classed generation result.
#' @export
bebel_chat <- function(
  model,
  message,
  greedy = FALSE,
  on_event = NULL,
  check_interrupt = TRUE,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL,
  poll_interval = 0.005
) {
  message <- S7::prop(BebelScalarText(value = message), "value")
  options <- BebelGenerationOptions(
    greedy = isTRUE(greedy),
    check_interrupt = isTRUE(check_interrupt),
    max_gen = if (is.null(max_gen)) NULL else as.numeric(max_gen),
    max_context = if (is.null(max_context)) NULL else as.numeric(max_context),
    max_think = if (is.null(max_think)) NULL else as.numeric(max_think),
    temperature = if (is.null(temperature)) NULL else as.numeric(temperature),
    top_k = if (is.null(top_k)) NULL else as.numeric(top_k),
    repeat_penalty = if (is.null(repeat_penalty)) NULL else as.numeric(repeat_penalty)
  )
  on_event <- normalize_bebel_on_event(on_event)
  job <- bebel_chat_async(
    model = model,
    message = message,
    greedy = S7::prop(options, "greedy"),
    max_gen = S7::prop(options, "max_gen"),
    max_context = S7::prop(options, "max_context"),
    max_think = S7::prop(options, "max_think"),
    temperature = S7::prop(options, "temperature"),
    top_k = S7::prop(options, "top_k"),
    repeat_penalty = S7::prop(options, "repeat_penalty")
  )
  bebel_async_wait(
    job,
    on_event = on_event,
    poll_interval = poll_interval,
    cancel_on_interrupt = S7::prop(options, "check_interrupt")
  )
}

#' Start a background raw generation job
#'
#' Async jobs run BebeLM generation on Rust worker threads and reuse the loaded
#' model weights. They are polled with `bebel_async_poll()` and collected with
#' `bebel_async_collect()`.
#'
#' @inheritParams bebel_generate
#' @return A `BebelAsyncJob`.
#' @export
bebel_generate_async <- function(
  model,
  prompt,
  greedy = FALSE,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
) {
  model <- S7::prop(BebelModelRef(value = list(model)), "value")[[1L]]
  prompt <- S7::prop(BebelScalarText(value = prompt), "value")
  options <- BebelGenerationOptions(
    greedy = isTRUE(greedy),
    check_interrupt = FALSE,
    max_gen = if (is.null(max_gen)) NULL else as.numeric(max_gen),
    max_context = if (is.null(max_context)) NULL else as.numeric(max_context),
    max_think = if (is.null(max_think)) NULL else as.numeric(max_think),
    temperature = if (is.null(temperature)) NULL else as.numeric(temperature),
    top_k = if (is.null(top_k)) NULL else as.numeric(top_k),
    repeat_penalty = if (is.null(repeat_penalty)) NULL else as.numeric(repeat_penalty)
  )
  job <- model$generate_async(
    prompt = prompt,
    greedy = S7::prop(options, "greedy"),
    max_gen = S7::prop(options, "max_gen"),
    max_context = S7::prop(options, "max_context"),
    max_think = S7::prop(options, "max_think"),
    temperature = S7::prop(options, "temperature"),
    top_k = S7::prop(options, "top_k"),
    repeat_penalty = S7::prop(options, "repeat_penalty")
  )
  class(job) <- c("bebelGenerateJob", "bebelAsyncJob", class(job))
  job
}

#' Start a background ChatML assistant reply job
#'
#' @inheritParams bebel_chat
#' @return A `BebelAsyncJob`.
#' @export
bebel_chat_async <- function(
  model,
  message,
  greedy = FALSE,
  max_gen = NULL,
  max_context = NULL,
  max_think = NULL,
  temperature = NULL,
  top_k = NULL,
  repeat_penalty = NULL
) {
  model <- S7::prop(BebelModelRef(value = list(model)), "value")[[1L]]
  message <- S7::prop(BebelScalarText(value = message), "value")
  options <- BebelGenerationOptions(
    greedy = isTRUE(greedy),
    check_interrupt = FALSE,
    max_gen = if (is.null(max_gen)) NULL else as.numeric(max_gen),
    max_context = if (is.null(max_context)) NULL else as.numeric(max_context),
    max_think = if (is.null(max_think)) NULL else as.numeric(max_think),
    temperature = if (is.null(temperature)) NULL else as.numeric(temperature),
    top_k = if (is.null(top_k)) NULL else as.numeric(top_k),
    repeat_penalty = if (is.null(repeat_penalty)) NULL else as.numeric(repeat_penalty)
  )
  job <- model$chat_async(
    message = message,
    greedy = S7::prop(options, "greedy"),
    max_gen = S7::prop(options, "max_gen"),
    max_context = S7::prop(options, "max_context"),
    max_think = S7::prop(options, "max_think"),
    temperature = S7::prop(options, "temperature"),
    top_k = S7::prop(options, "top_k"),
    repeat_penalty = S7::prop(options, "repeat_penalty")
  )
  class(job) <- c("bebelChatJob", "bebelAsyncJob", class(job))
  job
}

#' Start a background raw agent generation job
#'
#' The job runs on a cloned agent snapshot. The original agent's transcript and
#' decode cache are not mutated, while the model weights are shared.
#'
#' @param agent A `BebelAgent` object.
#' @return A `BebelAsyncJob`.
#' @export
bebel_agent_generate_async <- function(agent) {
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  job <- agent$generate_async()
  class(job) <- c("bebelAgentGenerateJob", "bebelAsyncJob", class(job))
  job
}

#' Start a background assistant-turn job
#'
#' @inheritParams bebel_agent_generate_async
#' @return A `BebelAsyncJob`.
#' @export
bebel_assistant_turn_async <- function(agent) {
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  job <- agent$assistant_turn_async()
  class(job) <- c("bebelAssistantTurnJob", "bebelAsyncJob", class(job))
  job
}

#' Start a background assistant-turn job that stops on tool-call close
#'
#' @inheritParams bebel_agent_generate_async
#' @return A `BebelAsyncJob`.
#' @export
bebel_assistant_turn_tool_stop_async <- function(agent) {
  agent <- S7::prop(BebelAgentRef(value = list(agent)), "value")[[1L]]
  job <- agent$assistant_turn_tool_stop_async()
  class(job) <- c("bebelAssistantTurnJob", "bebelAsyncJob", class(job))
  job
}

# Test whether a BebeLM async job has finished.
#
# Kept as an internal boolean wrapper around the Rust method. The public API is
# poll/collect, matching aio-style usage.
#
# @param job A `BebelAsyncJob`.
# @return `TRUE` when the result can be collected without waiting.
bebel_async_is_ready <- function(job) {
  job <- S7::prop(BebelAsyncJobRef(value = list(job)), "value")[[1L]]
  isTRUE(job$ready())
}

#' Poll a BebeLM async job
#'
#' @param job A `BebelAsyncJob`.
#' @return `"ready"` or `"pending"`.
#' @export
bebel_async_poll <- function(job) {
  if (bebel_async_is_ready(job)) "ready" else "pending"
}

#' Drain queued BebeLM async job events
#'
#' @param job A `BebelAsyncJob`.
#' @param max Optional maximum number of queued events to drain.
#' @return A list of generation event lists.
#' @export
bebel_async_events <- function(job, max = NULL) {
  job <- S7::prop(BebelAsyncJobRef(value = list(job)), "value")[[1L]]
  options <- BebelAsyncEventDrainOptions(max = if (is.null(max)) NULL else as.numeric(max))
  job$events(max = S7::prop(options, "max"))
}

#' Cancel a BebeLM async job
#'
#' Requests cancellation from Rust. A cancelled job stops at the next generation
#' checkpoint and raises an error when collected.
#'
#' @param job A `BebelAsyncJob`.
#' @return `TRUE` when this call set the cancellation flag for the first time.
#' @export
bebel_async_cancel <- function(job) {
  job <- S7::prop(BebelAsyncJobRef(value = list(job)), "value")[[1L]]
  isTRUE(job$cancel())
}

#' Collect a BebeLM async job result
#'
#' @param job A `BebelAsyncJob`.
#' @param wait If `FALSE`, return `NULL` when the job is still running.
#' @return A classed generation result, or `NULL`.
#' @export
bebel_async_collect <- function(job, wait = TRUE) {
  job_class <- class(job)
  job <- S7::prop(BebelAsyncJobRef(value = list(job)), "value")[[1L]]
  out <- job$result(wait = isTRUE(wait))
  if (is.null(out)) return(NULL)
  result_class <- if (inherits(job_class, "bebelChatJob")) {
    "bebelChatResult"
  } else if (inherits(job_class, "bebelAgentGenerateJob")) {
    "bebelAgentGenerateResult"
  } else if (inherits(job_class, "bebelAssistantTurnJob")) {
    "bebelAssistantTurnResult"
  } else if (inherits(job_class, "bebelGenerateJob")) {
    "bebelGenerateResult"
  } else {
    "bebelAsyncResult"
  }
  class(out) <- c(result_class, "bebelAsyncResult", "bebelGeneration", class(out))
  out
}

dispatch_bebel_async_events <- function(events, on_event) {
  if (is.null(on_event) || !length(events)) return(invisible(NULL))
  for (event in events) {
    on_event(event)
  }
  invisible(NULL)
}

#' Wait for a BebeLM async job
#'
#' Drains queued stream events on the R thread while polling the job, then
#' collects the finished result.
#'
#' @param job A `BebelAsyncJob`.
#' @param on_event Event handler function, named list of event-specific handlers,
#'   or `NULL`.
#' @param poll_interval Seconds to sleep between polls while the job is pending.
#' @param cancel_on_interrupt Whether an interrupted wait should request
#'   Rust-side job cancellation.
#' @return A classed generation result.
#' @export
bebel_async_wait <- function(job,
                             on_event = NULL,
                             poll_interval = 0.005,
                             cancel_on_interrupt = TRUE) {
  job <- S7::prop(BebelAsyncJobRef(value = list(job)), "value")[[1L]]
  on_event <- normalize_bebel_on_event(on_event)
  options <- BebelAsyncWaitOptions(
    poll_interval = as.numeric(poll_interval),
    cancel_on_interrupt = isTRUE(cancel_on_interrupt)
  )
  poll_interval <- S7::prop(options, "poll_interval")
  cancel_on_interrupt <- S7::prop(options, "cancel_on_interrupt")

  completed <- FALSE
  on.exit({
    if (!completed && cancel_on_interrupt && !bebel_async_is_ready(job)) {
      try(bebel_async_cancel(job), silent = TRUE)
    }
  }, add = TRUE)

  repeat {
    dispatch_bebel_async_events(bebel_async_events(job), on_event)
    out <- bebel_async_collect(job, wait = FALSE)
    if (!is.null(out)) {
      completed <- TRUE
      dispatch_bebel_async_events(bebel_async_events(job), on_event)
      return(out)
    }
    if (poll_interval > 0) {
      Sys.sleep(poll_interval)
    }
  }
}

#' Benchmark async BebeLM generation throughput
#'
#' Launches deterministic generation jobs in bounded async batches against one
#' loaded model and records per-job timing, token counts, event counts, and
#' aggregate throughput.
#'
#' @param model A `BebelModel` object.
#' @param prompts Character vector of prompts.
#' @param concurrency Maximum number of async jobs in flight.
#' @param repeats Number of times to repeat the prompt set.
#' @inheritParams bebel_generate
#' @return A `bebelGenerationBenchmark` list.
#' @export
bebel_benchmark_generation <- function(model,
                                       prompts,
                                       concurrency = min(length(prompts), 2L),
                                       repeats = 1L,
                                       greedy = TRUE,
                                       max_gen = 64L,
                                       max_context = NULL,
                                       max_think = 0L,
                                       temperature = NULL,
                                       top_k = NULL,
                                       repeat_penalty = NULL,
                                       poll_interval = 0.001) {
  model <- S7::prop(BebelModelRef(value = list(model)), "value")[[1L]]
  bench_options <- BebelGenerationBenchmarkOptions(
    prompts = prompts,
    concurrency = as.numeric(concurrency),
    repeats = as.numeric(repeats),
    poll_interval = as.numeric(poll_interval)
  )
  gen_options <- BebelGenerationOptions(
    greedy = isTRUE(greedy),
    check_interrupt = TRUE,
    max_gen = if (is.null(max_gen)) NULL else as.numeric(max_gen),
    max_context = if (is.null(max_context)) NULL else as.numeric(max_context),
    max_think = if (is.null(max_think)) NULL else as.numeric(max_think),
    temperature = if (is.null(temperature)) NULL else as.numeric(temperature),
    top_k = if (is.null(top_k)) NULL else as.numeric(top_k),
    repeat_penalty = if (is.null(repeat_penalty)) NULL else as.numeric(repeat_penalty)
  )

  prompts <- S7::prop(bench_options, "prompts")
  concurrency <- as.integer(S7::prop(bench_options, "concurrency"))
  repeats <- as.integer(S7::prop(bench_options, "repeats"))
  poll_interval <- S7::prop(bench_options, "poll_interval")

  tasks <- data.frame(
    job_id = seq_len(length(prompts) * repeats),
    prompt_id = rep(seq_along(prompts), times = repeats),
    repeat_id = rep(seq_len(repeats), each = length(prompts)),
    prompt = rep(prompts, times = repeats),
    stringsAsFactors = FALSE
  )

  active_jobs <- list()
  on.exit({
    for (job in active_jobs) {
      try(bebel_async_cancel(job), silent = TRUE)
    }
  }, add = TRUE)

  wall_start <- proc.time()[["elapsed"]]
  started_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%OS3%z")
  results <- vector("list", nrow(tasks))
  event_counts <- integer(nrow(tasks))
  launch_elapsed <- rep(NA_real_, nrow(tasks))
  finish_elapsed <- rep(NA_real_, nrow(tasks))

  for (first in seq(1L, nrow(tasks), by = concurrency)) {
    idx <- first:min(first + concurrency - 1L, nrow(tasks))
    jobs <- vector("list", length(idx))
    for (slot in seq_along(idx)) {
      task <- tasks[idx[[slot]], , drop = FALSE]
      launch_elapsed[[idx[[slot]]]] <- proc.time()[["elapsed"]] - wall_start
      jobs[[slot]] <- bebel_generate_async(
        model = model,
        prompt = task$prompt[[1L]],
        greedy = S7::prop(gen_options, "greedy"),
        max_gen = S7::prop(gen_options, "max_gen"),
        max_context = S7::prop(gen_options, "max_context"),
        max_think = S7::prop(gen_options, "max_think"),
        temperature = S7::prop(gen_options, "temperature"),
        top_k = S7::prop(gen_options, "top_k"),
        repeat_penalty = S7::prop(gen_options, "repeat_penalty")
      )
      active_jobs[[as.character(idx[[slot]])]] <- jobs[[slot]]
    }

    pending <- seq_along(idx)
    while (length(pending)) {
      completed_slots <- integer()
      for (slot in pending) {
        task_index <- idx[[slot]]
        events <- bebel_async_events(jobs[[slot]])
        event_counts[[task_index]] <- event_counts[[task_index]] + length(events)
        out <- bebel_async_collect(jobs[[slot]], wait = FALSE)
        if (!is.null(out)) {
          events <- bebel_async_events(jobs[[slot]])
          event_counts[[task_index]] <- event_counts[[task_index]] + length(events)
          finish_elapsed[[task_index]] <- proc.time()[["elapsed"]] - wall_start
          task <- tasks[task_index, , drop = FALSE]
          results[[task_index]] <- data.frame(
            job_id = task$job_id,
            prompt_id = task$prompt_id,
            repeat_id = task$repeat_id,
            prompt = task$prompt,
            text = trimws(out$text),
            stop = out$stop,
            prompt_chars = nchar(task$prompt, type = "chars"),
            prompt_tokens = out$prompt_tokens,
            generated_tokens = out$generated_tokens,
            prefill_seconds = out$prefill_seconds,
            decode_seconds = out$decode_seconds,
            prefill_tps = out$prefill_tps,
            decode_tps = out$decode_tps,
            launch_elapsed = launch_elapsed[[task_index]],
            finish_elapsed = finish_elapsed[[task_index]],
            wall_seconds = finish_elapsed[[task_index]] - launch_elapsed[[task_index]],
            event_count = event_counts[[task_index]],
            stringsAsFactors = FALSE
          )
          active_jobs[[as.character(task_index)]] <- NULL
          completed_slots <- c(completed_slots, slot)
        }
      }
      pending <- setdiff(pending, completed_slots)
      if (length(pending) && poll_interval > 0) {
        Sys.sleep(poll_interval)
      }
    }
  }

  jobs <- do.call(rbind, results)
  row.names(jobs) <- NULL
  elapsed_seconds <- proc.time()[["elapsed"]] - wall_start
  total_prompt_tokens <- sum(jobs$prompt_tokens)
  total_generated_tokens <- sum(jobs$generated_tokens)
  total_decode_seconds <- sum(jobs$decode_seconds)
  aggregate <- data.frame(
    job_count = nrow(jobs),
    prompt_count = length(prompts),
    repeats = repeats,
    concurrency = concurrency,
    elapsed_seconds = elapsed_seconds,
    total_prompt_tokens = total_prompt_tokens,
    total_generated_tokens = total_generated_tokens,
    generated_tps_wall = if (elapsed_seconds > 0) total_generated_tokens / elapsed_seconds else NA_real_,
    generated_tps_decode = if (total_decode_seconds > 0) total_generated_tokens / total_decode_seconds else NA_real_,
    mean_job_wall_seconds = mean(jobs$wall_seconds),
    mean_decode_tps = mean(jobs$decode_tps),
    stringsAsFactors = FALSE
  )

  out <- list(
    started_at = started_at,
    model = model$info(),
    backend = rbebelm_backend_info(),
    parameters = list(
      greedy = S7::prop(gen_options, "greedy"),
      max_gen = S7::prop(gen_options, "max_gen"),
      max_context = S7::prop(gen_options, "max_context"),
      max_think = S7::prop(gen_options, "max_think"),
      temperature = S7::prop(gen_options, "temperature"),
      top_k = S7::prop(gen_options, "top_k"),
      repeat_penalty = S7::prop(gen_options, "repeat_penalty")
    ),
    aggregate = aggregate,
    jobs = jobs
  )
  class(out) <- c("bebelGenerationBenchmark", "list")
  out
}

#' @export
print.bebelGenerationBenchmark <- function(x, ...) {
  cat("<BebeLM generation benchmark>\n")
  cat("  jobs: ", x$aggregate$job_count, "\n", sep = "")
  cat("  concurrency: ", x$aggregate$concurrency, "\n", sep = "")
  cat("  elapsed: ", sprintf("%.3f s", x$aggregate$elapsed_seconds), "\n", sep = "")
  cat("  generated throughput: ", sprintf("%.2f tok/s", x$aggregate$generated_tps_wall), "\n", sep = "")
  invisible(x)
}

#' @export
print.BebelAsyncJob <- function(x, ...) {
  cat("<BebelAsyncJob>\n")
  kind <- if (inherits(x, "bebelChatJob")) {
    "chat"
  } else if (inherits(x, "bebelAgentGenerateJob")) {
    "agent_generate"
  } else if (inherits(x, "bebelAssistantTurnJob")) {
    "assistant_turn"
  } else if (inherits(x, "bebelGenerateJob")) {
    "generate"
  } else {
    "unknown"
  }
  cat("  kind: ", kind, "\n", sep = "")
  cat("  status: ", bebel_async_poll(x), "\n", sep = "")
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
#' @param x A result returned by [bebel_generate()], [bebel_chat()], or
#'   `bebel_async_collect()`.
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
