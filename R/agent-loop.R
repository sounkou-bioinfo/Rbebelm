#' Create an Agent-loop policy
#'
#' Policies configure the UI-independent loop. The queue mode names mirror Pi's
#' core agent loop: queued steering/follow-up messages are drained either
#' `"one-at-a-time"` or `"all"`.
#'
#' @param max_steps Maximum assistant/tool iterations per run.
#' @param steering_mode How queued steering messages are drained.
#' @param follow_up_mode How queued follow-up messages are drained.
#' @param before_tool_call Optional function `(call, context, loop)` called before
#'   dispatching a tool. Return `list(block = TRUE, message = "...")` to block.
#' @return A `bebelLoopPolicy` object.
#' @export
bebel_loop_policy <- function(
  max_steps = 8L,
  steering_mode = c("one-at-a-time", "all"),
  follow_up_mode = c("one-at-a-time", "all"),
  before_tool_call = NULL
) {
  steering_mode <- match.arg(steering_mode)
  follow_up_mode <- match.arg(follow_up_mode)
  if (!is.null(before_tool_call) && !is.function(before_tool_call)) {
    stop("before_tool_call must be a function or NULL", call. = FALSE)
  }
  max_steps <- as.integer(max_steps)
  if (!length(max_steps) || is.na(max_steps) || max_steps < 1L) {
    stop("max_steps must be a positive integer", call. = FALSE)
  }
  structure(
    list(
      max_steps = max_steps,
      steering_mode = steering_mode,
      follow_up_mode = follow_up_mode,
      before_tool_call = before_tool_call
    ),
    class = "bebelLoopPolicy"
  )
}

bebel_loop_check <- function(loop) {
  if (!inherits(loop, "bebelAgentLoop")) stop("loop must be a bebelAgentLoop", call. = FALSE)
  invisible(loop)
}

bebel_loop_emit <- function(loop, type, ...) {
  loop$event_seq <- loop$event_seq + 1L
  event <- c(list(type = type, seq = loop$event_seq, time = Sys.time(), state = loop$state), list(...))
  loop$events[[length(loop$events) + 1L]] <- event
  if (!identical(type, "hook_error")) {
    tryCatch(
      call_bebel_hook(loop$hooks, type, event = event, loop = loop, context = loop$context, agent = loop$agent),
      error = function(e) {
        loop$event_seq <- loop$event_seq + 1L
        loop$events[[length(loop$events) + 1L]] <- list(
          type = "hook_error",
          seq = loop$event_seq,
          time = Sys.time(),
          state = loop$state,
          hook = type,
          message = conditionMessage(e)
        )
      }
    )
    tryCatch(
      call_bebel_hook(loop$hooks, "event", event = event, loop = loop, context = loop$context, agent = loop$agent),
      error = function(e) NULL
    )
    for (sink in loop$event_sinks %||% list()) {
      tryCatch(
        sink(event = event, loop = loop, context = loop$context, agent = loop$agent),
        error = function(e) NULL
      )
    }
  }
  invisible(event)
}

bebel_loop_set_state <- function(loop, state) {
  old <- loop$state
  if (!identical(old, state)) {
    loop$state <- state
    bebel_loop_emit(loop, "state_change", from = old, to = state)
  }
  invisible(loop)
}

bebel_loop_emit_queue_update <- function(loop) {
  bebel_loop_emit(
    loop,
    "queue_update",
    steering = loop$queue$steering,
    followUp = loop$queue$followUp
  )
}

bebel_loop_queue_message <- function(loop, text, queue = c("steering", "followUp")) {
  queue <- match.arg(queue)
  text <- as.character(text)
  if (!length(text) || !nzchar(text[[1L]])) stop("message must be non-empty", call. = FALSE)
  loop$queue[[queue]] <- c(loop$queue[[queue]], text[[1L]])
  bebel_loop_emit_queue_update(loop)
  invisible(loop)
}

bebel_loop_drain_queue <- function(loop, queue = c("steering", "followUp")) {
  queue <- match.arg(queue)
  messages <- loop$queue[[queue]]
  if (!length(messages)) return(character())
  mode <- if (identical(queue, "steering")) loop$policy$steering_mode else loop$policy$follow_up_mode
  if (identical(mode, "all")) {
    drained <- messages
    loop$queue[[queue]] <- character()
  } else {
    drained <- messages[[1L]]
    loop$queue[[queue]] <- messages[-1L]
  }
  bebel_loop_emit_queue_update(loop)
  drained
}

bebel_loop_slice_since <- function(x, n) {
  if (length(x) <= n) return(list())
  x[seq.int(n + 1L, length(x))]
}

bebel_loop_message_record <- function(text, source) {
  list(role = "user", content = as.character(text), source = source, timestamp = Sys.time())
}

bebel_loop_normalize_session <- function(session) {
  if (isTRUE(session)) return(bebel_session_create())
  if (is.null(session) || isFALSE(session)) return(NULL)
  if (inherits(session, "bebelSession")) return(session)
  if (is.character(session) && length(session) == 1L) return(bebel_session_open(session))
  stop("session must be TRUE, FALSE, NULL, a bebelSession, or a session JSONL path", call. = FALSE)
}

bebel_loop_session_append_user <- function(loop, text, source) {
  if (is.null(loop$session)) return(invisible(NULL))
  bebel_session_append_message(
    loop$session,
    role = "user",
    content = as.character(text),
    source = source
  )
}

bebel_loop_session_append_assistant <- function(loop, turn) {
  if (is.null(loop$session)) return(invisible(NULL))
  info <- tryCatch(bebel_backend_info(loop$agent), error = function(e) list())
  text <- as.character(turn$text %||% "")
  provider <- info$provider %||% info$backend %||% info$name %||% "unknown"
  model <- info$model %||% info$model_id %||% info$modelId %||% info$path %||% "unknown"
  usage <- list(
    input = as.integer(turn$prompt_tokens %||% turn$input_tokens %||% 0L),
    output = as.integer(turn$tokens %||% turn$output_tokens %||% turn$generated_tokens %||% 0L),
    cacheRead = as.integer(turn$cache_read %||% 0L),
    cacheWrite = as.integer(turn$cache_write %||% 0L),
    totalTokens = as.integer((turn$prompt_tokens %||% turn$input_tokens %||% 0L) + (turn$tokens %||% turn$output_tokens %||% turn$generated_tokens %||% 0L))
  )
  bebel_session_append_message(
    loop$session,
    role = "assistant",
    content = list(list(type = "text", text = text)),
    provider = provider,
    model = model,
    usage = usage,
    stopReason = turn$stop %||% "stop",
    details = list(result = turn, backend_info = info)
  )
}

bebel_loop_session_append_tool_result <- function(loop, call, text, ok = TRUE) {
  if (is.null(loop$session)) return(invisible(NULL))
  bebel_session_append_message(
    loop$session,
    role = "toolResult",
    content = list(list(type = "text", text = as.character(text))),
    toolName = call$name %||% "unknown",
    toolCallId = call$id %||% call$name %||% "tool",
    isError = !isTRUE(ok),
    details = list(call = call)
  )
}

bebel_loop_deliver_user_messages <- function(loop, messages, source) {
  if (!length(messages)) return(invisible(FALSE))
  for (text in messages) {
    message <- bebel_loop_message_record(text, source = source)
    bebel_loop_emit(loop, "message_start", message = message, source = source)
    bebel_backend_append_user(loop$agent, text)
    bebel_loop_session_append_user(loop, text, source = source)
    loop$user_messages[[length(loop$user_messages) + 1L]] <- message
    bebel_loop_emit(loop, "message_end", message = message, source = source)
  }
  invisible(TRUE)
}

bebel_loop_deliver_steering <- function(loop) {
  messages <- bebel_loop_drain_queue(loop, "steering")
  if (!length(messages)) return(invisible(FALSE))
  bebel_loop_deliver_user_messages(loop, messages, source = "steer")
  invisible(TRUE)
}

bebel_loop_deliver_follow_up <- function(loop) {
  messages <- bebel_loop_drain_queue(loop, "followUp")
  if (!length(messages)) return(invisible(FALSE))
  bebel_loop_deliver_user_messages(loop, messages, source = "followUp")
  invisible(TRUE)
}

#' Create a stateful BebeLM agent loop
#'
#' `bebel_agent_loop()` is the UI-independent controller inspired by Pi's
#' Agent/AgentSession versus InteractiveMode split. It owns lifecycle state,
#' queues, policy, hooks, and tool dispatch. Consoles, RPC handlers, and TUIs
#' should consume this loop rather than embedding agent business logic.
#'
#' @param agent An object implementing `BebelAgentBackend`.
#' @param tools A list of `bebel_tool()` objects or named functions.
#' @param context Private mutable context passed to tools and hooks.
#' @param policy A [bebel_loop_policy()] object.
#' @param hooks Optional named hooks. Loop hooks may observe `state_change`,
#'   `queue_update`, `message_start`, `message_end`, `model_event`,
#'   `tool_request`, `tool_result`, `tool_error`, `tool_denied`, `observation`,
#'   `command_start`, `command_end`, and `loop_end`.
#' @param extensions Optional list of [bebel_extension()] objects.
#' @param session Session persistence setting. `TRUE` creates an `bebelSession`
#'   under `bebel_session_dir()`, `FALSE`/`NULL` disables persistence, an
#'   `bebelSession` reuses that store, and a character path opens a JSONL session.
#' @param parse_tool_call Function converting tool-call text into one or more
#'   call records.
#' @param on_event Optional event callback or handler list for model stream events.
#' @param check_interrupt Check for Ctrl-C during generation.
#' @return A `bebelAgentLoop` environment.
#' @export
bebel_agent_loop <- function(
  agent,
  tools = list(),
  context = new.env(parent = emptyenv()),
  policy = bebel_loop_policy(),
  hooks = list(),
  extensions = list(),
  session = TRUE,
  parse_tool_call = bebel_parse_tool_calls,
  on_event = NULL,
  check_interrupt = TRUE
) {
  bebel_assert_implements(agent, BebelAgentBackend, arg = "agent")
  tools <- normalize_bebel_tools(tools)
  extensions <- bebel_normalize_extensions(extensions)
  contributed_tools <- bebel_extension_collect_tools(extensions)
  contributed_commands <- bebel_extension_collect_commands(extensions)
  contributed_skill_providers <- bebel_extension_collect_skill_providers(extensions)
  contributed_prompt_template_providers <- bebel_extension_collect_prompt_template_providers(extensions)
  contributed_hooks <- bebel_extension_collect_hooks(extensions)
  user_hooks <- bebel_validate_hook_list(hooks)
  if (!inherits(policy, "bebelLoopPolicy")) stop("policy must be a bebelLoopPolicy", call. = FALSE)
  if (!is.function(parse_tool_call)) stop("parse_tool_call must be a function", call. = FALSE)
  session <- bebel_loop_normalize_session(session)

  loop <- new.env(parent = emptyenv())
  loop$agent <- agent
  loop$user_tools <- tools
  loop$user_hooks <- user_hooks
  loop$tools <- bebel_merge_named_lists(list(tools, contributed_tools), what = "tool")
  loop$commands <- contributed_commands
  loop$skill_providers <- contributed_skill_providers
  loop$prompt_template_providers <- contributed_prompt_template_providers
  loop$extensions <- extensions
  loop$context <- context
  loop$session <- session
  loop$policy <- policy
  loop$hooks <- bebel_combine_hook_lists(user_hooks, contributed_hooks)
  loop$before_tool_call_hooks <- bebel_collect_before_tool_call_hooks(user_hooks, contributed_hooks)
  loop$parse_tool_call <- parse_tool_call
  loop$on_event <- on_event
  loop$check_interrupt <- check_interrupt
  loop$state <- "idle"
  loop$events <- list()
  loop$event_seq <- 0L
  loop$event_sinks <- list()
  loop$turns <- list()
  loop$tool_calls <- list()
  loop$observations <- list()
  loop$user_messages <- list()
  loop$step <- 0L
  loop$queue <- list(steering = character(), followUp = character())
  loop$created_at <- Sys.time()
  class(loop) <- c("bebelAgentLoop", "environment")
  bebel_loop_emit(
    loop,
    "loop_created",
    tools = bebel_loop_names(loop$tools),
    commands = bebel_loop_names(loop$commands),
    extensions = bebel_loop_names(loop$extensions),
    skill_providers = bebel_loop_names(loop$skill_providers),
    prompt_template_providers = bebel_loop_names(loop$prompt_template_providers),
    session_file = if (!is.null(loop$session)) bebel_session_file(loop$session) else NULL
  )
  loop
}

#' Create an agent loop from an R-native agent session
#'
#' @param session A `bebelRAgent` from [bebel_r_agent()].
#' @param agent_session Session persistence setting passed to [bebel_agent_loop()].
#' @inheritParams bebel_agent_loop
#' @return A `bebelAgentLoop` environment.
#' @export
bebel_r_agent_loop <- function(
  session,
  policy = bebel_loop_policy(),
  hooks = list(),
  extensions = list(),
  agent_session = TRUE,
  parse_tool_call = bebel_parse_tool_calls,
  on_event = NULL,
  check_interrupt = TRUE
) {
  bebel_agent_layer_stopif(inherits(session, "bebelRAgent"), "session must be a bebelRAgent")
  extensions <- if (is.null(extensions)) list() else if (bebel_implements(extensions, BebelAgentExtension)) list(extensions) else extensions
  extensions <- c(list(r_agent_commands = bebel_r_agent_loop_extension(session)), extensions)
  bebel_agent_loop(
    session$agent,
    tools = bebel_agent_as_bebel_tools(session$tools),
    context = session$context,
    policy = policy,
    hooks = hooks,
    extensions = extensions,
    session = agent_session,
    parse_tool_call = parse_tool_call,
    on_event = on_event,
    check_interrupt = check_interrupt
  )
}

#' Inspect agent-loop state
#'
#' @param loop A `bebelAgentLoop`.
#' @return A list snapshot of loop state.
#' @export
bebel_loop_state <- function(loop) {
  bebel_loop_check(loop)
  list(
    state = loop$state,
    step = loop$step,
    turns = length(loop$turns),
    user_messages = length(loop$user_messages),
    tool_calls = length(loop$tool_calls),
    observations = length(loop$observations),
    extensions = bebel_loop_names(loop$extensions),
    commands = bebel_loop_names(loop$commands),
    skill_providers = bebel_loop_names(loop$skill_providers),
    prompt_template_providers = bebel_loop_names(loop$prompt_template_providers),
    queue = loop$queue,
    steering_mode = loop$policy$steering_mode,
    follow_up_mode = loop$policy$follow_up_mode,
    session_id = if (!is.null(loop$session)) bebel_session_header(loop$session)$id else NULL,
    session_file = if (!is.null(loop$session)) bebel_session_file(loop$session) else NULL,
    backend_info = tryCatch(bebel_backend_info(loop$agent), error = function(e) list(error = conditionMessage(e)))
  )
}

#' Return agent-loop events
#'
#' @param loop A `bebelAgentLoop`.
#' @param since Return events with sequence number greater than `since`.
#' @return A list of event records.
#' @export
bebel_loop_events <- function(loop, since = 0L) {
  bebel_loop_check(loop)
  since <- as.integer(since)
  if (!length(since) || is.na(since)) since <- 0L
  Filter(function(event) event$seq > since, loop$events)
}

#' Queue a steering message
#'
#' Steering messages mirror Pi's `steer()` queue: they are delivered after the
#' current assistant/tool turn and before the next model call.
#'
#' @param loop A `bebelAgentLoop`.
#' @param message Text to queue.
#' @return Invisibly returns `loop`.
#' @export
bebel_loop_steer <- function(loop, message) {
  bebel_loop_check(loop)
  bebel_loop_queue_message(loop, message, "steering")
}

#' Queue a follow-up message
#'
#' Follow-up messages mirror Pi's `followUp()` queue: they are delivered only
#' when the loop would otherwise stop because there are no tool calls or steering
#' messages left.
#'
#' @inheritParams bebel_loop_steer
#' @export
bebel_loop_follow_up <- function(loop, message) {
  bebel_loop_check(loop)
  bebel_loop_queue_message(loop, message, "followUp")
}

bebel_loop_before_tool_call <- function(loop, call) {
  before <- loop$policy$before_tool_call
  decisions <- list()
  if (!is.null(before)) decisions <- c(decisions, list(before))
  decisions <- c(decisions, loop$before_tool_call_hooks)
  if (!length(decisions)) return(list(block = FALSE))
  for (fn in decisions) {
    decision <- fn(call, loop$context, loop)
    if (is.null(decision) || isTRUE(decision)) next
    if (isFALSE(decision)) return(list(block = TRUE, message = paste0("tool blocked: ", call$name)))
    if (is.list(decision)) {
      if (isTRUE(decision$block)) return(decision)
      next
    }
    stop("before_tool_call must return NULL, TRUE, FALSE, or a list", call. = FALSE)
  }
  list(block = FALSE)
}

bebel_loop_record_observation <- function(loop, call, text, ok = TRUE) {
  obs <- list(call = call, text = text, ok = ok, time = Sys.time())
  loop$observations[[length(loop$observations) + 1L]] <- obs
  bebel_loop_session_append_tool_result(loop, call, text, ok = ok)
  bebel_loop_emit(loop, "observation", observation = obs, call = call)
  obs
}

#' Run one agent-loop assistant/tool step
#'
#' @param loop A `bebelAgentLoop`.
#' @return A list with `turn`, `tool_blocks`, and `done`.
#' @export
bebel_loop_step <- function(loop) {
  bebel_loop_check(loop)
  if (loop$state %in% c("cancelled", "error")) stop("loop is not runnable in state ", loop$state, call. = FALSE)

  bebel_loop_deliver_steering(loop)
  loop$step <- loop$step + 1L
  step <- loop$step
  tool_blocks <- character()
  user_event <- normalize_bebel_on_event(loop$on_event)
  collector <- bebel_event_handler(
    tool_call_end = function(event) {
      tool_blocks <<- c(tool_blocks, event$content)
      bebel_loop_emit(loop, "model_event", model_event = event, step = step)
      if (!is.null(user_event)) user_event(event)
    },
    default = function(event) {
      bebel_loop_emit(loop, "model_event", model_event = event, step = step)
      if (!is.null(user_event)) user_event(event)
    }
  )

  bebel_loop_set_state(loop, "generating")
  bebel_loop_emit(loop, "turn_start", step = step)
  turn <- tryCatch(
    {
      if (length(loop$tools)) {
        bebel_backend_assistant_turn(loop$agent, on_event = collector, check_interrupt = loop$check_interrupt, stop_on_tool_call = TRUE)
      } else {
        bebel_backend_assistant_turn(loop$agent, on_event = collector, check_interrupt = loop$check_interrupt, stop_on_tool_call = FALSE)
      }
    },
    error = function(e) {
      bebel_loop_set_state(loop, "error")
      bebel_loop_emit(loop, "loop_error", error = e, message = conditionMessage(e), step = step)
      stop(e)
    }
  )
  loop$turns[[length(loop$turns) + 1L]] <- turn
  bebel_loop_session_append_assistant(loop, turn)
  bebel_loop_emit(loop, "turn_end", turn = turn, step = step)

  if (!length(tool_blocks)) {
    bebel_loop_set_state(loop, "idle")
    return(list(turn = turn, tool_blocks = tool_blocks, done = TRUE, had_tool_calls = FALSE))
  }

  bebel_loop_set_state(loop, "tool_pending")
  for (block in tool_blocks) {
    parsed <- tryCatch(
      loop$parse_tool_call(block),
      error = function(e) {
        preview <- block
        if (nchar(preview) > 500L) preview <- paste0(substr(preview, 1L, 500L), "...")
        simpleError(paste0("cannot parse tool call ", sQuote(preview), ": ", conditionMessage(e)))
      }
    )
    if (inherits(parsed, "error")) {
      call <- list(name = "parse_tool_call", arguments = list(raw = block), raw = block)
      loop$tool_calls[[length(loop$tool_calls) + 1L]] <- call
      bebel_loop_emit(loop, "tool_error", call = call, error = parsed, step = step)
      text <- format_bebel_tool_result(call, NULL, parsed)
      bebel_loop_record_observation(loop, call, text, ok = FALSE)
      bebel_backend_append_tool_result(loop$agent, text)
      next
    }

    calls <- normalize_parsed_bebel_calls(parsed)
    block_results <- character()
    for (call in calls) {
      loop$tool_calls[[length(loop$tool_calls) + 1L]] <- call
      bebel_loop_emit(loop, "tool_request", call = call, step = step)
      decision <- tryCatch(bebel_loop_before_tool_call(loop, call), error = function(e) e)
      if (inherits(decision, "error")) {
        bebel_loop_emit(loop, "tool_error", call = call, error = decision, step = step)
        text <- format_bebel_tool_result(call, NULL, decision)
        block_results <- c(block_results, text)
        bebel_loop_record_observation(loop, call, text, ok = FALSE)
        next
      }
      if (isTRUE(decision$block)) {
        err <- simpleError(decision$message %||% paste0("tool blocked: ", call$name))
        bebel_loop_emit(loop, "tool_denied", call = call, decision = decision, step = step)
        text <- format_bebel_tool_result(call, NULL, err)
        block_results <- c(block_results, text)
        bebel_loop_record_observation(loop, call, text, ok = FALSE)
        next
      }
      tool <- loop$tools[[call$name]]
      if (is.null(tool)) {
        err <- simpleError(paste0("unknown tool: ", call$name))
        bebel_loop_emit(loop, "tool_error", call = call, error = err, step = step)
        text <- format_bebel_tool_result(call, NULL, err)
        block_results <- c(block_results, text)
        bebel_loop_record_observation(loop, call, text, ok = FALSE)
        next
      }
      bebel_loop_set_state(loop, "tool_running")
      result <- tryCatch(invoke_bebel_tool(tool, call, loop$context), error = function(e) e)
      if (inherits(result, "error")) {
        bebel_loop_emit(loop, "tool_error", call = call, error = result, step = step)
        text <- format_bebel_tool_result(call, NULL, result)
        block_results <- c(block_results, text)
        bebel_loop_record_observation(loop, call, text, ok = FALSE)
      } else {
        bebel_loop_emit(loop, "tool_result", call = call, result = result, step = step)
        text <- format_bebel_tool_result(call, result)
        block_results <- c(block_results, text)
        bebel_loop_record_observation(loop, call, text, ok = TRUE)
      }
    }
    bebel_backend_append_tool_result(loop$agent, paste(block_results, collapse = "\n"))
  }
  bebel_loop_set_state(loop, "idle")
  list(turn = turn, tool_blocks = tool_blocks, done = FALSE, had_tool_calls = TRUE)
}

#' Run an agent loop
#'
#' @param loop A `bebelAgentLoop`.
#' @param prompt Optional user prompt to append before running.
#' @param max_steps Optional per-call step cap. Defaults to `loop$policy$max_steps`.
#' @return A `bebelAgentLoopRun` / `bebelAgentRun` result.
#' @export
bebel_loop_run <- function(loop, prompt = NULL, max_steps = NULL) {
  bebel_loop_check(loop)
  start_events <- length(loop$events)
  if (!is.null(prompt)) {
    prompt <- as.character(prompt)[[1L]]
    if (bebel_loop_execute_command(loop, prompt)) {
      return(structure(
        list(turns = list(), tool_calls = list(), context = loop$context, backend_info = bebel_backend_info(loop$agent), events = bebel_loop_slice_since(loop$events, start_events), loop = loop, done = TRUE),
        class = c("bebelAgentLoopRun", "bebelAgentRun")
      ))
    }
    bebel_loop_deliver_user_messages(loop, prompt, source = "prompt")
  }

  max_steps <- as.integer(max_steps %||% loop$policy$max_steps)
  if (!length(max_steps) || is.na(max_steps) || max_steps < 1L) max_steps <- loop$policy$max_steps
  start_turns <- length(loop$turns)
  start_calls <- length(loop$tool_calls)
  bebel_loop_set_state(loop, "running")
  steps <- 0L
  done <- FALSE
  while (steps < max_steps) {
    steps <- steps + 1L
    out <- bebel_loop_step(loop)
    if (!isTRUE(out$had_tool_calls)) {
      if (isTRUE(bebel_loop_deliver_steering(loop))) next
      if (isTRUE(bebel_loop_deliver_follow_up(loop))) next
      done <- TRUE
      break
    }
  }
  bebel_loop_set_state(loop, "idle")
  bebel_loop_emit(loop, "loop_end", steps = steps, done = done)

  structure(
    list(
      turns = bebel_loop_slice_since(loop$turns, start_turns),
      tool_calls = bebel_loop_slice_since(loop$tool_calls, start_calls),
      context = loop$context,
      backend_info = bebel_backend_info(loop$agent),
      events = bebel_loop_slice_since(loop$events, start_events),
      loop = loop,
      done = done
    ),
    class = c("bebelAgentLoopRun", "bebelAgentRun")
  )
}

#' Prompt an agent loop
#'
#' If the loop is idle, this appends the prompt and runs the loop. If the loop is
#' already active, `streaming_behavior` must be `"steer"` or `"followUp"`, matching
#' Pi's prompt queue semantics.
#'
#' @param loop A `bebelAgentLoop`.
#' @param text User prompt text.
#' @param streaming_behavior `NULL`, `"steer"`, or `"followUp"`.
#' @return A loop run result when idle, otherwise invisibly returns `loop`.
#' @export
bebel_loop_prompt <- function(loop, text, streaming_behavior = NULL) {
  bebel_loop_check(loop)
  text <- as.character(text)[[1L]]
  if (bebel_loop_execute_command(loop, text)) return(invisible(loop))
  if (!identical(loop$state, "idle")) {
    if (is.null(streaming_behavior)) {
      stop("Agent is already processing. Specify streaming_behavior ('steer' or 'followUp') to queue the message.", call. = FALSE)
    }
    streaming_behavior <- match.arg(streaming_behavior, c("steer", "followUp"))
    if (identical(streaming_behavior, "steer")) bebel_loop_steer(loop, text) else bebel_loop_follow_up(loop, text)
    return(invisible(loop))
  }
  bebel_loop_run(loop, prompt = text)
}

#' Clear queued steering and follow-up messages
#'
#' @param loop A `bebelAgentLoop`.
#' @return A list containing cleared `steering` and `followUp` messages.
#' @export
bebel_loop_clear_queue <- function(loop) {
  bebel_loop_check(loop)
  old <- loop$queue
  loop$queue <- list(steering = character(), followUp = character())
  bebel_loop_emit_queue_update(loop)
  old
}

#' Cancel an agent loop
#'
#' @param loop A `bebelAgentLoop`.
#' @return Invisibly returns `loop`.
#' @export
bebel_loop_cancel <- function(loop) {
  bebel_loop_check(loop)
  bebel_loop_set_state(loop, "cancelled")
  cleared <- bebel_loop_clear_queue(loop)
  bebel_loop_emit(loop, "cancelled", cleared = cleared)
  invisible(loop)
}

bebel_loop_tool_descriptor <- function(tool) {
  list(
    name = tool$name,
    description = tool$description %||% tool$name,
    inputSchema = normalize_bebel_tool_schema_json(tool$schema %||% list())
  )
}

bebel_rpc_sanitize <- function(x, depth = 0L) {
  if (depth > 8L) return("<max-depth>")
  if (is.null(x) || is.logical(x) || is.numeric(x) || is.character(x)) return(x)
  if (inherits(x, "POSIXt")) return(format(x, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"))
  if (inherits(x, "condition")) return(list(message = conditionMessage(x), class = class(x)))
  if (is.environment(x)) return("<environment>")
  if (is.function(x)) return("<function>")
  if (is.raw(x)) return(paste(as.character(x), collapse = ""))
  if (is.atomic(x)) return(as.vector(x))
  if (is.list(x)) return(lapply(x, bebel_rpc_sanitize, depth = depth + 1L))
  as.character(x)
}

bebel_rpc_ndjson <- function(x) {
  paste0(bebel_rpc_json(bebel_rpc_sanitize(x)), "\n")
}

bebel_loop_request_handler <- function(type, fun, response_type = NULL, rpc_methods = character()) {
  structure(
    list(type = type, fun = fun, response_type = response_type %||% type, rpc_methods = rpc_methods),
    class = "bebelLoopRequestHandler"
  )
}

bebel_loop_clear_runtime <- function(loop) {
  bebel_backend_clear(loop$agent)
  loop$turns <- list()
  loop$tool_calls <- list()
  loop$observations <- list()
  loop$user_messages <- list()
  loop$queue <- list(steering = character(), followUp = character())
  bebel_loop_emit(loop, "session_clear")
  list(ok = TRUE, state = bebel_loop_state(loop))
}

bebel_loop_run_turn_request <- function(loop, params) {
  prompt <- params$prompt %||% stop("turn command requires prompt", call. = FALSE)
  run <- bebel_loop_run(loop, prompt = prompt, max_steps = as.integer(params$max_steps %||% loop$policy$max_steps))
  last <- if (length(run$turns)) run$turns[[length(run$turns)]] else list(text = "")
  list(
    text = last$text %||% "",
    turns = run$turns,
    tool_calls = run$tool_calls,
    backend_info = run$backend_info,
    events = run$events,
    state = bebel_loop_state(loop),
    done = isTRUE(run$done)
  )
}

bebel_loop_execute_command_request <- function(loop, params) {
  command <- params$command %||% stop("execute_command requires command", call. = FALSE)
  start_events <- length(loop$events)
  handled <- bebel_loop_execute_command(loop, command)
  events <- bebel_loop_slice_since(loop$events, start_events)
  end <- Filter(function(event) identical(event$type, "command_end"), events)
  value <- if (length(end)) end[[length(end)]]$result else NULL
  list(result = handled, value = value, events = events, state = bebel_loop_state(loop))
}

bebel_loop_request_handlers <- function() {
  list(
    session_info = bebel_loop_request_handler(
      "session_info",
      function(loop, params) list(state = bebel_loop_state(loop)),
      rpc_methods = "session/info"
    ),
    tools_list = bebel_loop_request_handler(
      "tools_list",
      function(loop, params) list(tools = unname(lapply(loop$tools, bebel_loop_tool_descriptor))),
      rpc_methods = "tools/list"
    ),
    commands_list = bebel_loop_request_handler(
      "commands_list",
      function(loop, params) list(commands = bebel_loop_command_catalog(loop)),
      rpc_methods = "commands/list"
    ),
    catalog = bebel_loop_request_handler(
      "catalog",
      function(loop, params) list(catalog = bebel_loop_catalog(loop)),
      rpc_methods = "catalog"
    ),
    transcript = bebel_loop_request_handler(
      "transcript",
      function(loop, params) list(transcript = bebel_backend_transcript(loop$agent)),
      rpc_methods = "session/transcript"
    ),
    events = bebel_loop_request_handler(
      "events",
      function(loop, params) list(events = bebel_loop_events(loop, since = as.integer(params$since %||% 0L))),
      rpc_methods = "events/list"
    ),
    clear = bebel_loop_request_handler(
      "clear",
      function(loop, params) bebel_loop_clear_runtime(loop),
      response_type = "clear_result",
      rpc_methods = "session/clear"
    ),
    turn = bebel_loop_request_handler(
      "turn",
      function(loop, params) bebel_loop_run_turn_request(loop, params),
      response_type = "turn_result",
      rpc_methods = "turn"
    ),
    steer = bebel_loop_request_handler(
      "steer",
      function(loop, params) {
        message <- params$message %||% params$prompt %||% stop("steer command requires message", call. = FALSE)
        bebel_loop_steer(loop, message)
        list(ok = TRUE, state = bebel_loop_state(loop))
      },
      response_type = "steer_result",
      rpc_methods = "steer"
    ),
    followUp = bebel_loop_request_handler(
      "followUp",
      function(loop, params) {
        message <- params$message %||% params$prompt %||% stop("followUp command requires message", call. = FALSE)
        bebel_loop_follow_up(loop, message)
        list(ok = TRUE, state = bebel_loop_state(loop))
      },
      response_type = "followUp_result",
      rpc_methods = "followUp"
    ),
    execute_command = bebel_loop_request_handler(
      "execute_command",
      function(loop, params) bebel_loop_execute_command_request(loop, params),
      response_type = "command_result",
      rpc_methods = "command/execute"
    )
  )
}

bebel_loop_request_handler_for <- function(type) {
  type <- as.character(type %||% "")[[1L]]
  handlers <- bebel_loop_request_handlers()
  handler <- handlers[[type]]
  if (is.null(handler)) stop("unknown command type: ", type, call. = FALSE)
  handler
}

bebel_loop_rpc_method_map <- function() {
  handlers <- bebel_loop_request_handlers()
  methods <- unlist(lapply(names(handlers), function(type) {
    stats::setNames(rep(type, length(handlers[[type]]$rpc_methods)), handlers[[type]]$rpc_methods)
  }), use.names = TRUE)
  methods
}

bebel_loop_request_handle <- function(loop, type, params = list()) {
  bebel_loop_check(loop)
  params <- params %||% list()
  handler <- bebel_loop_request_handler_for(type)
  list(handler = handler, value = handler$fun(loop, params))
}

bebel_loop_command_handle <- function(loop, req) {
  type <- req$type %||% req$command %||% ""
  params <- req$params %||% req
  out <- bebel_loop_request_handle(loop, type, params)
  c(list(type = out$handler$response_type), out$value)
}

bebel_loop_rpc_handle <- function(loop, req) {
  bebel_loop_check(loop)
  method <- req$method %||% ""
  id <- req$id %||% NULL
  params <- req$params %||% list()
  result <- tryCatch({
    type <- unname(bebel_loop_rpc_method_map()[method])
    if (!length(type) || is.na(type)) stop("unknown method: ", method, call. = FALSE)
    bebel_loop_request_handle(loop, type, params)$value
  }, error = function(e) {
    structure(list(code = -32000L, message = conditionMessage(e)), class = "bebel_rpc_error")
  })
  if (inherits(result, "bebel_rpc_error")) {
    bebel_rpc_response(id, error = unclass(result))
  } else {
    bebel_rpc_response(id, result = result)
  }
}

#' Serve a generic Rbebelm agent loop over HTTP(S)
#'
#' This optional SDK surface exposes a backend-agnostic [bebel_agent_loop()] over
#' a transport endpoint with `GET /stream` NDJSON events, `POST /command` typed
#' commands, and `POST /rpc` JSON-RPC compatibility. The endpoint may be local
#' HTTP, remote HTTP, or HTTPS/TLS when `nanonext` is configured with TLS.
#' External frontends such as the native `rbebelm-tui` binary call the loop
#' protocol and never assume the backend is a concrete `BebelAgent`.
#'
#' @param loop A `bebelAgentLoop`.
#' @param url URL to listen on, e.g. `"http://127.0.0.1:8080"` or
#'   `"https://0.0.0.0:8443"`.
#' @param tls Optional TLS configuration from `nanonext::tls_config()` for
#'   HTTPS/WSS endpoints.
#' @return A `nanoServer` object from `nanonext`.
#' @export
bebel_loop_rpc_server <- function(loop, url = "http://127.0.0.1:8080", tls = NULL) {
  bebel_loop_check(loop)
  bebel_agent_require("nanonext")

  stream_conns <- new.env(parent = emptyenv())
  broadcast <- function(record) {
    data <- bebel_rpc_ndjson(record)
    for (id in ls(stream_conns, all.names = TRUE)) {
      conn <- stream_conns[[id]]
      tryCatch(conn$send(data), error = function(e) stream_conns[[id]] <- NULL)
    }
    invisible(NULL)
  }

  loop$event_sinks <- loop$event_sinks %||% list()
  sink_id <- paste0("bebel_loop_rpc_server_", as.integer(Sys.time()), "_", sample.int(.Machine$integer.max, 1L))
  loop$event_sinks[[sink_id]] <- function(event, loop, context, agent, ...) {
    broadcast(list(type = "event", seq = event$seq, event = event))
    invisible(NULL)
  }

  req_header <- function(req, name) {
    headers <- req$headers %||% list()
    nms <- names(headers)
    if (!length(headers) || is.null(nms)) return(NULL)
    hit <- which(tolower(nms) == tolower(name))
    if (!length(hit)) return(NULL)
    value <- headers[[hit[[1L]]]]
    if (!length(value)) return(NULL)
    value <- as.character(value[[1L]])
    if (!nzchar(value)) NULL else value
  }

  parse_since <- function(req) {
    header <- req_header(req, "Last-Event-ID")
    if (!is.null(header)) return(suppressWarnings(as.integer(header)))
    uri <- req$uri %||% ""
    if (!grepl("?", uri, fixed = TRUE)) return(0L)
    query <- sub("^[^?]*\\?", "", uri)
    parts <- strsplit(query, "&", fixed = TRUE)[[1L]]
    hit <- parts[startsWith(parts, "since=")]
    if (!length(hit)) return(0L)
    suppressWarnings(as.integer(utils::URLdecode(sub("^since=", "", hit[[1L]]))))
  }

  handlers <- list(
    nanonext::handler("/health", function(req) {
      list(status = 200L, headers = c("Content-Type" = "application/json"), body = bebel_rpc_json(list(ok = TRUE)))
    }, method = "GET"),
    nanonext::handler_stream(
      "/stream",
      on_request = function(conn, req) {
        conn$set_header("Content-Type", "application/x-ndjson")
        conn$set_header("Cache-Control", "no-cache")
        id <- as.character(conn$id)
        stream_conns[[id]] <- conn
        conn$send(bebel_rpc_ndjson(list(type = "stream_open", seq = loop$event_seq, state = bebel_loop_state(loop))))
        since <- parse_since(req)
        if (!is.na(since) && since > 0L) {
          for (event in bebel_loop_events(loop, since = since)) {
            conn$send(bebel_rpc_ndjson(list(type = "event", seq = event$seq, event = event)))
          }
        }
      },
      on_close = function(conn) {
        stream_conns[[as.character(conn$id)]] <- NULL
      },
      method = "GET"
    ),
    nanonext::handler("/command", function(req) {
      body <- rawToChar(req$body %||% raw())
      parsed <- tryCatch(bebel_json_read(body), error = function(e) NULL)
      if (is.null(parsed)) {
        response <- list(type = "error", error = list(code = -32700L, message = "parse error"))
      } else {
        response <- tryCatch(
          bebel_loop_command_handle(loop, parsed),
          error = function(e) list(type = "error", error = list(code = -32000L, message = conditionMessage(e)))
        )
      }
      list(status = 200L, headers = c("Content-Type" = "application/json"), body = bebel_rpc_json(bebel_rpc_sanitize(response)))
    }, method = "POST"),
    nanonext::handler("/rpc", function(req) {
      body <- rawToChar(req$body %||% raw())
      parsed <- tryCatch(bebel_json_read(body), error = function(e) NULL)
      if (is.null(parsed)) {
        response <- bebel_rpc_response(NULL, error = list(code = -32700L, message = "parse error"))
      } else {
        response <- bebel_loop_rpc_handle(loop, parsed)
      }
      list(status = 200L, headers = c("Content-Type" = "application/json"), body = bebel_rpc_json(response))
    }, method = "POST")
  )
  nanonext::http_server(url = url, handlers = handlers, tls = tls)
}

#' @export
print.bebelAgentLoop <- function(x, ...) {
  s <- bebel_loop_state(x)
  cat("<bebelAgentLoop>\n")
  cat("  state: ", s$state, "\n", sep = "")
  cat("  turns: ", s$turns, "\n", sep = "")
  cat("  tool calls: ", s$tool_calls, "\n", sep = "")
  cat("  queued: ", length(s$queue$steering), " steering; ", length(s$queue$followUp), " followUp\n", sep = "")
  cat("  extensions: ", paste(s$extensions, collapse = ", "), "\n", sep = "")
  cat("  session: ", s$session_file %||% "<none>", "\n", sep = "")
  invisible(x)
}
