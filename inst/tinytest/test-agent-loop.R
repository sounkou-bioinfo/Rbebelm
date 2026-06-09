library(Rbebelm)

fake_loop <- function(policy = bebel_loop_policy()) {
  loop <- new.env(parent = emptyenv())
  loop$agent <- NULL
  loop$context <- new.env(parent = emptyenv())
  loop$policy <- policy
  loop$user_tools <- list()
  loop$user_hooks <- list()
  loop$hooks <- list()
  loop$before_tool_call_hooks <- list()
  loop$commands <- list()
  loop$extensions <- list()
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
  class(loop) <- c("bebelAgentLoop", "environment")
  loop
}

policy <- bebel_loop_policy(max_steps = 3L, steering_mode = "one-at-a-time", follow_up_mode = "all")
expect_equal(policy$max_steps, 3L)
expect_equal(policy$steering_mode, "one-at-a-time")
expect_equal(policy$follow_up_mode, "all")

loop <- fake_loop(policy)
bebel_loop_steer(loop, "first")
bebel_loop_steer(loop, "second")
expect_equal(loop$queue$steering, c("first", "second"))
expect_equal(Rbebelm:::bebel_loop_drain_queue(loop, "steering"), "first")
expect_equal(loop$queue$steering, "second")
expect_true(any(vapply(loop$events, function(x) identical(x$type, "queue_update"), logical(1))))

bebel_loop_follow_up(loop, "one")
bebel_loop_follow_up(loop, "two")
expect_equal(Rbebelm:::bebel_loop_drain_queue(loop, "followUp"), c("one", "two"))
expect_equal(loop$queue$followUp, character())

cmd <- bebel_loop_command("remember", function(args, loop, context) {
  context$remembered <- args
  paste("remembered", args)
}, description = "Remember text.")
ext <- bebel_extension(
  "demo",
  tools = list(echo = bebel_tool("echo", function(args) args, description = "Echo args.")),
  commands = list(cmd),
  hooks = list(before_tool_call = function(call, context, loop) {
    if (identical(call$name, "blocked")) list(block = TRUE, message = "blocked by extension") else NULL
  }),
  keybindings = list(remember = "ctrl+r"),
  widgets = list(status = "demo")
)
expect_true(inherits(ext, "bebelExtension"))
manifest <- bebel_extension_manifest(ext)
expect_equal(manifest$name, "demo")
expect_equal(manifest$tools, "echo")
expect_equal(names(manifest$commands), "remember")

loop2 <- fake_loop()
extensions <- Rbebelm:::bebel_normalize_extensions(list(ext))
loop2$extensions <- extensions
loop2$commands <- Rbebelm:::bebel_extension_collect_commands(extensions)
loop2$before_tool_call_hooks <- Rbebelm:::bebel_collect_before_tool_call_hooks(list(), Rbebelm:::bebel_extension_collect_hooks(extensions))
expect_true(bebel_loop_execute_command(loop2, "/remember hello world"))
expect_equal(loop2$context$remembered, "hello world")
expect_false(bebel_loop_execute_command(loop2, "/unknown hello"))

request_handlers <- Rbebelm:::bebel_loop_request_handlers()
expect_true(all(c("session_info", "commands_list", "execute_command") %in% names(request_handlers)))
command_result <- Rbebelm:::bebel_loop_command_handle(loop2, list(type = "execute_command", command = "/remember via command"))
expect_equal(command_result$type, "command_result")
expect_true(command_result$result)
expect_equal(command_result$value, "remembered via command")
rpc_result <- Rbebelm:::bebel_loop_rpc_handle(loop2, list(jsonrpc = "2.0", id = 7L, method = "command/execute", params = list(command = "/remember via rpc")))
expect_equal(rpc_result$id, 7L)
expect_true(rpc_result$result$result)
expect_equal(rpc_result$result$value, "remembered via rpc")
commands_result <- Rbebelm:::bebel_loop_command_handle(loop2, list(type = "commands_list"))
expect_equal(commands_result$type, "commands_list")
expect_true("remember" %in% commands_result$commands$name)
expect_error(Rbebelm:::bebel_loop_command_handle(loop2, list(type = "not_a_request_type")), "unknown command type")

catalog <- bebel_loop_command_catalog(loop2)
expect_equal(catalog$name, "remember")
expect_true(grepl("Remember", catalog$description))

decision <- Rbebelm:::bebel_loop_before_tool_call(loop2, list(name = "blocked", arguments = list()))
expect_true(decision$block)
expect_true(grepl("blocked", decision$message))

loop3 <- fake_loop()
bebel_loop_register_extension(loop3, ext)
expect_equal(names(loop3$extensions), "demo")
expect_equal(names(loop3$tools), "echo")
expect_equal(names(loop3$commands), "remember")
expect_error(bebel_loop_register_extension(loop3, ext), "already registered")
expect_true(any(vapply(loop3$events, function(x) identical(x$type, "extension_registered"), logical(1))))
expect_true(any(vapply(loop3$events, function(x) identical(x$type, "catalog_changed"), logical(1))))
bebel_loop_unregister_extension(loop3, "demo")
expect_equal(length(loop3$extensions), 0L)
expect_equal(length(loop3$tools), 0L)
expect_equal(length(loop3$commands), 0L)
expect_true(any(vapply(loop3$events, function(x) identical(x$type, "extension_unregistered"), logical(1))))

CustomExtensionS3 <- S7::new_S3_class("rbebelmCustomExtensionTest")
S7::method(bebel_extension_manifest, CustomExtensionS3) <- function(extension) {
  list(
    name = extension$name,
    tools = names(extension$tools),
    commands = lapply(extension$commands, function(command) list(name = command$name, description = command$description, usage = command$usage)),
    hooks = names(extension$hooks),
    skill_providers = character(),
    prompt_template_providers = character(),
    keybindings = list(),
    widgets = list(),
    metadata = list(kind = "custom")
  )
}
S7::method(bebel_extension_tools, CustomExtensionS3) <- function(extension) extension$tools
S7::method(bebel_extension_commands, CustomExtensionS3) <- function(extension) extension$commands
S7::method(bebel_extension_hooks, CustomExtensionS3) <- function(extension) extension$hooks
S7::method(bebel_extension_skill_providers, CustomExtensionS3) <- function(extension) list()
S7::method(bebel_extension_prompt_template_providers, CustomExtensionS3) <- function(extension) list()
custom_ext <- structure(
  list(
    name = "custom",
    tools = list(),
    commands = list(ping = bebel_loop_command("ping", function(args, loop, context) {
      context$ping <- args
      TRUE
    })),
    hooks = list()
  ),
  class = "rbebelmCustomExtensionTest"
)
loop4 <- fake_loop()
bebel_loop_register_extension(loop4, custom_ext)
expect_equal(names(loop4$commands), "ping")
expect_true(bebel_loop_execute_command(loop4, "/ping pong"))
expect_equal(loop4$context$ping, "pong")

cleared <- bebel_loop_clear_queue(loop)
expect_true(is.list(cleared))
expect_equal(loop$queue$steering, character())
expect_equal(loop$queue$followUp, character())
