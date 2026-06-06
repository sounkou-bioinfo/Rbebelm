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
#' @return A named list describing installed, supported, requested, and selected backends.
#' @export
rbebelm_backend_info <- function() {
  .Call(Rbebelm_backend_info_impl)
}

#' Inspect CPU SIMD support used by backend dispatch
#'
#' @return A named list of logical CPU feature checks.
#' @export
rbebelm_cpuid_info <- function() {
  .Call(Rbebelm_cpuid_info_impl)
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
#' @param agent A `BebelAgent` object.
#' @return Updated agent info.
#' @export
bebel_clear <- function(agent) {
  check_bebel_agent(agent)
  agent$clear()
}

#' Return a BebeLM agent token transcript
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
#' @param agent A `BebelAgent` object.
#' @return Transcript text.
#' @export
bebel_transcript <- function(agent) {
  check_bebel_agent(agent)
  agent$transcript()
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
  kind <- if (inherits(x, "bebelChatResult")) "BebeLM chat result" else "BebeLM generation result"
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
