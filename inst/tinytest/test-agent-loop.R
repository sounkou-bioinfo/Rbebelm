library(Rbebelm)

fake_loop <- function(policy = bebel_loop_policy()) {
  loop <- new.env(parent = emptyenv())
  loop$agent <- NULL
  loop$context <- new.env(parent = emptyenv())
  loop$policy <- policy
  loop$hooks <- list()
  loop$before_tool_call_hooks <- list()
  loop$commands <- list()
  loop$extensions <- list()
  loop$state <- "idle"
  loop$events <- list()
  loop$event_seq <- 0L
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

catalog <- bebel_loop_command_catalog(loop2)
expect_equal(catalog$name, "remember")
expect_true(grepl("Remember", catalog$description))

decision <- Rbebelm:::bebel_loop_before_tool_call(loop2, list(name = "blocked", arguments = list()))
expect_true(decision$block)
expect_true(grepl("blocked", decision$message))

cleared <- bebel_loop_clear_queue(loop)
expect_true(is.list(cleared))
expect_equal(loop$queue$steering, character())
expect_equal(loop$queue$followUp, character())
