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
    tools = names(loop$tools),
    commands = names(loop$commands),
    extensions = names(loop$extensions),
    skill_providers = names(loop$skill_providers),
    prompt_template_providers = names(loop$prompt_template_providers),
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
    extensions = names(loop$extensions),
    commands = names(loop$commands),
    skill_providers = names(loop$skill_providers),
    prompt_template_providers = names(loop$prompt_template_providers),
    queue = loop$queue,
    steering_mode = loop$policy$steering_mode,
    follow_up_mode = loop$policy$follow_up_mode,
    session_id = if (!is.null(loop$session)) bebel_session_header(loop$session)$id else NULL,
    session_file = if (!is.null(loop$session)) bebel_session_file(loop$session) else NULL,
    backend_info = bebel_backend_info(loop$agent)
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
