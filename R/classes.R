#' Scalar non-empty text
#'
#' @param value A non-empty character scalar.
#' @export
BebelScalarText <- S7::new_class(
  "BebelScalarText",
  properties = list(value = S7::class_character),
  validator = function(self) {
    value <- S7::prop(self, "value")
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "`value` must be a non-empty character scalar."
    }
  }
)

#' BebeLM model reference
#'
#' @param value A one-element list containing a `BebelModel`.
#' @export
BebelModelRef <- S7::new_class(
  "BebelModelRef",
  properties = list(value = S7::class_list),
  validator = function(self) {
    value <- S7::prop(self, "value")
    if (length(value) != 1L || !inherits(value[[1L]], "BebelModel")) {
      "`value` must contain one BebelModel."
    }
  }
)

#' BebeLM agent reference
#'
#' @param value A one-element list containing a `BebelAgent`.
#' @export
BebelAgentRef <- S7::new_class(
  "BebelAgentRef",
  properties = list(value = S7::class_list),
  validator = function(self) {
    value <- S7::prop(self, "value")
    if (length(value) != 1L || !inherits(value[[1L]], "BebelAgent")) {
      "`value` must contain one BebelAgent."
    }
  }
)

#' BebeLM async job reference
#'
#' @param value A one-element list containing a `BebelAsyncJob`.
#' @export
BebelAsyncJobRef <- S7::new_class(
  "BebelAsyncJobRef",
  properties = list(value = S7::class_list),
  validator = function(self) {
    value <- S7::prop(self, "value")
    if (length(value) != 1L || !inherits(value[[1L]], "BebelAsyncJob")) {
      "`value` must contain one BebelAsyncJob."
    }
  }
)

#' Async event drain options
#'
#' @param max Optional non-negative whole-number event limit.
#' @export
BebelAsyncEventDrainOptions <- S7::new_class(
  "BebelAsyncEventDrainOptions",
  properties = list(max = S7::class_any),
  validator = function(self) {
    max <- S7::prop(self, "max")
    if (!is.null(max) && (
      !is.numeric(max) ||
        length(max) != 1L ||
        is.na(max) ||
        !is.finite(max) ||
        max < 0 ||
        max != floor(max)
    )) {
      "`max` must be NULL or a non-negative whole number."
    }
  }
)

#' Async wait options
#'
#' @param poll_interval Seconds to sleep between polls while a job is pending.
#' @param cancel_on_interrupt Whether an interrupted wait should request Rust-side
#'   job cancellation.
#' @export
BebelAsyncWaitOptions <- S7::new_class(
  "BebelAsyncWaitOptions",
  properties = list(poll_interval = S7::class_numeric, cancel_on_interrupt = S7::class_logical),
  validator = function(self) {
    errors <- character()
    poll_interval <- S7::prop(self, "poll_interval")
    if (length(poll_interval) != 1L ||
        is.na(poll_interval) ||
        !is.finite(poll_interval) ||
        poll_interval < 0) {
      errors <- c(errors, "`poll_interval` must be a finite non-negative numeric scalar.")
    }
    cancel_on_interrupt <- S7::prop(self, "cancel_on_interrupt")
    if (length(cancel_on_interrupt) != 1L || is.na(cancel_on_interrupt)) {
      errors <- c(errors, "`cancel_on_interrupt` must be TRUE or FALSE.")
    }
    if (length(errors)) errors else NULL
  }
)

#' Generation benchmark options
#'
#' @param prompts Character vector of prompts.
#' @param concurrency Maximum number of async jobs in flight.
#' @param repeats Number of times to repeat the prompt set.
#' @param poll_interval Seconds to sleep between monitor polls.
#' @export
BebelGenerationBenchmarkOptions <- S7::new_class(
  "BebelGenerationBenchmarkOptions",
  properties = list(
    prompts = S7::class_character,
    concurrency = S7::class_numeric,
    repeats = S7::class_numeric,
    poll_interval = S7::class_numeric
  ),
  validator = function(self) {
    errors <- character()
    prompts <- S7::prop(self, "prompts")
    if (!length(prompts) || anyNA(prompts) || any(!nzchar(prompts))) {
      errors <- c(errors, "`prompts` must be a non-empty character vector without missing or empty values.")
    }
    for (name in c("concurrency", "repeats")) {
      value <- S7::prop(self, name)
      if (length(value) != 1L || is.na(value) || !is.finite(value) || value < 1 || value != floor(value)) {
        errors <- c(errors, paste0("`", name, "` must be a positive whole number."))
      }
    }
    poll_interval <- S7::prop(self, "poll_interval")
    if (length(poll_interval) != 1L ||
        is.na(poll_interval) ||
        !is.finite(poll_interval) ||
        poll_interval < 0) {
      errors <- c(errors, "`poll_interval` must be a finite non-negative numeric scalar.")
    }
    if (length(errors)) errors else NULL
  }
)

#' BebeLM tool reference
#'
#' @param value A one-element list containing a `BebelToolSpec`.
#' @export
BebelToolRef <- S7::new_class(
  "BebelToolRef",
  properties = list(value = S7::class_list),
  validator = function(self) {
    value <- S7::prop(self, "value")
    if (length(value) != 1L || !S7::S7_inherits(value[[1L]], BebelToolSpec)) {
      "`value` must contain one BebelToolSpec."
    }
  }
)

#' Model loading options
#'
#' @param path Path to a GGUF weights file.
#' @param num_threads Optional positive whole-number Rayon thread count.
#' @export
BebelModelLoadOptions <- S7::new_class(
  "BebelModelLoadOptions",
  properties = list(path = S7::class_character, num_threads = S7::class_any),
  validator = function(self) {
    path <- S7::prop(self, "path")
    if (length(path) != 1L || is.na(path) || !nzchar(path)) {
      return("`path` must be a non-empty character scalar.")
    }
    num_threads <- S7::prop(self, "num_threads")
    if (!is.null(num_threads) && (
      !is.numeric(num_threads) ||
        length(num_threads) != 1L ||
        is.na(num_threads) ||
        !is.finite(num_threads) ||
        num_threads < 1 ||
        num_threads != floor(num_threads)
    )) {
      return("`num_threads` must be NULL or a positive whole number.")
    }
    NULL
  }
)

#' Generation options
#'
#' @param greedy Use deterministic greedy decoding.
#' @param check_interrupt Check for R user interrupts during synchronous generation.
#' @param max_gen,max_context,max_think Optional generation limits.
#' @param temperature,top_k,repeat_penalty Optional sampling settings.
#' @export
BebelGenerationOptions <- S7::new_class(
  "BebelGenerationOptions",
  properties = list(
    greedy = S7::class_logical,
    check_interrupt = S7::class_logical,
    max_gen = S7::class_any,
    max_context = S7::class_any,
    max_think = S7::class_any,
    temperature = S7::class_any,
    top_k = S7::class_any,
    repeat_penalty = S7::class_any
  ),
  validator = function(self) {
    errors <- character()

    for (name in c("greedy", "check_interrupt")) {
      value <- S7::prop(self, name)
      if (length(value) != 1L || is.na(value)) {
        errors <- c(errors, paste0("`", name, "` must be TRUE or FALSE."))
      }
    }

    for (name in c("max_gen", "max_think", "top_k")) {
      value <- S7::prop(self, name)
      if (!is.null(value) && (
        !is.numeric(value) ||
          length(value) != 1L ||
          is.na(value) ||
          !is.finite(value) ||
          value < 0 ||
          value != floor(value)
      )) {
        errors <- c(errors, paste0("`", name, "` must be NULL or a non-negative whole number."))
      }
    }

    value <- S7::prop(self, "max_context")
    if (!is.null(value) && (
      !is.numeric(value) ||
        length(value) != 1L ||
        is.na(value) ||
        !is.finite(value) ||
        value < 1 ||
        value != floor(value)
    )) {
      errors <- c(errors, "`max_context` must be NULL or a positive whole number.")
    }

    value <- S7::prop(self, "temperature")
    if (!is.null(value) && (
      !is.numeric(value) ||
        length(value) != 1L ||
        is.na(value) ||
        !is.finite(value) ||
        value < 0
    )) {
      errors <- c(errors, "`temperature` must be NULL or a finite non-negative number.")
    }

    value <- S7::prop(self, "repeat_penalty")
    if (!is.null(value) && (
      !is.numeric(value) ||
        length(value) != 1L ||
        is.na(value) ||
        !is.finite(value) ||
        value <= 0
    )) {
      errors <- c(errors, "`repeat_penalty` must be NULL or a finite positive number.")
    }

    if (length(errors)) errors else NULL
  }
)

#' Agent construction options
#'
#' @param greedy Use deterministic greedy decoding.
#' @param max_gen,max_context,max_think Optional generation limits.
#' @param temperature,top_k,repeat_penalty Optional sampling settings.
#' @export
BebelAgentOptions <- S7::new_class(
  "BebelAgentOptions",
  properties = list(
    greedy = S7::class_logical,
    max_gen = S7::class_any,
    max_context = S7::class_any,
    max_think = S7::class_any,
    temperature = S7::class_any,
    top_k = S7::class_any,
    repeat_penalty = S7::class_any
  ),
  validator = function(self) {
    probe <- tryCatch(
      BebelGenerationOptions(
        greedy = S7::prop(self, "greedy"),
        check_interrupt = TRUE,
        max_gen = S7::prop(self, "max_gen"),
        max_context = S7::prop(self, "max_context"),
        max_think = S7::prop(self, "max_think"),
        temperature = S7::prop(self, "temperature"),
        top_k = S7::prop(self, "top_k"),
        repeat_penalty = S7::prop(self, "repeat_penalty")
      ),
      error = function(e) e
    )
    if (inherits(probe, "error")) conditionMessage(probe) else NULL
  }
)

#' Agent configuration update
#'
#' @param greedy Optional logical decoding-mode update.
#' @param max_gen,max_context,max_think Optional generation-limit updates.
#' @param temperature,top_k,repeat_penalty Optional sampling-setting updates.
#' @export
BebelAgentConfigureOptions <- S7::new_class(
  "BebelAgentConfigureOptions",
  properties = list(
    greedy = S7::class_any,
    max_gen = S7::class_any,
    max_context = S7::class_any,
    max_think = S7::class_any,
    temperature = S7::class_any,
    top_k = S7::class_any,
    repeat_penalty = S7::class_any
  ),
  validator = function(self) {
    errors <- character()

    value <- S7::prop(self, "greedy")
    if (!is.null(value) && (!is.logical(value) || length(value) != 1L || is.na(value))) {
      errors <- c(errors, "`greedy` must be NULL, TRUE, or FALSE.")
    }

    probe <- tryCatch(
      BebelGenerationOptions(
        greedy = FALSE,
        check_interrupt = TRUE,
        max_gen = S7::prop(self, "max_gen"),
        max_context = S7::prop(self, "max_context"),
        max_think = S7::prop(self, "max_think"),
        temperature = S7::prop(self, "temperature"),
        top_k = S7::prop(self, "top_k"),
        repeat_penalty = S7::prop(self, "repeat_penalty")
      ),
      error = function(e) e
    )
    if (inherits(probe, "error")) {
      errors <- c(errors, sub("^<BebelGenerationOptions> object is invalid:\n- ", "", conditionMessage(probe)))
    }

    if (length(errors)) errors else NULL
  }
)

#' Embedding options
#'
#' @param add_bos Whether to prepend the BOS token before embedding.
#' @param normalize Whether to L2-normalize each embedding row.
#' @param pooling Hidden-state pooling mode, `"mean"` or `"last"`.
#' @param token_batch_size Number of tokens per Rust batched prefill/matmul call.
#' @param sequence_batch_size Number of texts per independent-sequence embedding
#'   batch.
#' @param check_interrupt Whether long embedding runs should poll R interrupts
#'   between texts and token batches.
#' @export
BebelEmbeddingOptions <- S7::new_class(
  "BebelEmbeddingOptions",
  properties = list(
    add_bos = S7::class_logical,
    normalize = S7::class_logical,
    pooling = S7::class_character,
    token_batch_size = S7::class_numeric,
    sequence_batch_size = S7::class_numeric,
    check_interrupt = S7::class_logical
  ),
  validator = function(self) {
    errors <- character()
    for (name in c("add_bos", "normalize", "check_interrupt")) {
      value <- S7::prop(self, name)
      if (length(value) != 1L || is.na(value)) {
        errors <- c(errors, paste0("`", name, "` must be TRUE or FALSE."))
      }
    }
    pooling <- S7::prop(self, "pooling")
    if (length(pooling) != 1L || is.na(pooling) || !pooling %in% c("mean", "last")) {
      errors <- c(errors, "`pooling` must be \"mean\" or \"last\".")
    }
    for (name in c("token_batch_size", "sequence_batch_size")) {
      value <- S7::prop(self, name)
      if (length(value) != 1L ||
          is.na(value) ||
          value < 1 ||
          value != as.integer(value)) {
        errors <- c(errors, paste0("`", name, "` must be a positive integer scalar."))
      }
    }
    if (length(errors)) errors else NULL
  }
)

#' R tool exposed to BebeLM
#'
#' @param name Tool name exposed to the model and dispatcher.
#' @param fun R function called for matching tool calls.
#' @param description Optional tool description.
#' @param schema Optional JSON-schema-like list or JSON string.
#' @export
BebelToolSpec <- S7::new_class(
  "BebelToolSpec",
  properties = list(name = S7::class_character, fun = S7::class_any, description = S7::class_any, schema = S7::class_any),
  validator = function(self) {
    errors <- character()
    name <- S7::prop(self, "name")
    if (length(name) != 1L || is.na(name) || !nzchar(name)) {
      errors <- c(errors, "`name` must be a non-empty character scalar.")
    }
    if (!is.function(S7::prop(self, "fun"))) {
      errors <- c(errors, "`fun` must be a function.")
    }
    description <- S7::prop(self, "description")
    if (!is.null(description) && (
      !is.character(description) ||
        length(description) != 1L ||
        is.na(description)
    )) {
      errors <- c(errors, "`description` must be NULL or a character scalar.")
    }
    schema <- S7::prop(self, "schema")
    if (!is.null(schema) && !is.list(schema) && !(is.character(schema) && length(schema) == 1L && !is.na(schema))) {
      errors <- c(errors, "`schema` must be NULL, a list, or a JSON string.")
    }
    if (length(errors)) errors else NULL
  }
)

#' Agent run options
#'
#' @param max_steps Maximum assistant/tool iterations.
#' @param check_interrupt Check for R user interrupts during synchronous generation.
#' @export
BebelAgentRunOptions <- S7::new_class(
  "BebelAgentRunOptions",
  properties = list(max_steps = S7::class_numeric, check_interrupt = S7::class_logical),
  validator = function(self) {
    errors <- character()
    max_steps <- S7::prop(self, "max_steps")
    if (length(max_steps) != 1L || is.na(max_steps) || !is.finite(max_steps) || max_steps < 1 || max_steps != floor(max_steps)) {
      errors <- c(errors, "`max_steps` must be a positive whole number.")
    }
    check_interrupt <- S7::prop(self, "check_interrupt")
    if (length(check_interrupt) != 1L || is.na(check_interrupt)) {
      errors <- c(errors, "`check_interrupt` must be TRUE or FALSE.")
    }
    if (length(errors)) errors else NULL
  }
)
