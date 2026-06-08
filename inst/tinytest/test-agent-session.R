library(Rbebelm)

tmp <- tempfile("rbebelm-session-")
dir.create(tmp)

session <- agent_session_create(cwd = tmp, session_dir = tmp, name = "demo")
expect_true(inherits(session, "agentSession"))
expect_true(file.exists(agent_session_file(session)))
expect_equal(agent_session_header(session)$version, 3L)

u1 <- agent_session_append_message(session, "user", "hello", source = "test")
a1 <- agent_session_append_message(session, "assistant", list(list(type = "text", text = "hi")), provider = "fake", model = "fake-model", stopReason = "stop")
expect_equal(agent_session_leaf_id(session), a1)
expect_equal(length(agent_session_entries(session)), 3L)

agent_session_append_custom(session, "counter", list(n = 1L))
agent_session_append_custom_message(session, "context", "extra context", display = FALSE)
ctx <- agent_session_context(session)
expect_true(length(ctx$messages) >= 3L)
expect_true(any(vapply(ctx$messages, function(x) identical(x$role, "custom"), logical(1))))
expect_equal(ctx$model$modelId, "fake-model")

agent_session_checkout(session, u1)
u2 <- agent_session_append_message(session, "user", "branch")
expect_equal(agent_session_leaf_id(session), u2)
branch <- agent_session_branch(session)
branch_ids <- vapply(branch, `[[`, character(1), "id")
expect_equal(tail(branch_ids, 2L), c(u1, u2))

tree <- agent_session_tree(session)
expect_true(length(tree) >= 1L)
expect_true(length(tree[[1L]]$children) >= 1L)

agent_session_append_label(session, u1, "checkpoint")
expect_true(any(vapply(agent_session_entries(session), function(x) identical(x$type, "label"), logical(1))))

opened <- agent_session_open(agent_session_file(session))
expect_equal(agent_session_header(opened)$id, agent_session_header(session)$id)
expect_equal(length(agent_session_entries(opened)), length(agent_session_entries(session)))

forked <- agent_session_fork(agent_session_file(session), cwd = tmp, session_dir = tmp)
expect_true(!identical(agent_session_header(forked)$id, agent_session_header(session)$id))
expect_equal(normalizePath(agent_session_header(forked)$parentSession, winslash = "/"), normalizePath(agent_session_file(session), winslash = "/"))
expect_equal(length(agent_session_entries(forked)), length(agent_session_entries(session)))

cloned <- agent_session_clone_branch(session, leaf_id = u2, session_dir = tmp)
expect_true(!identical(agent_session_header(cloned)$id, agent_session_header(session)$id))
cloned_ids <- vapply(agent_session_entries(cloned), `[[`, character(1), "id")
expect_true(u2 %in% cloned_ids)
expect_false(a1 %in% cloned_ids)

listed <- agent_session_list(session_dir = tmp)
expect_true(nrow(listed) >= 2L)
expect_true(agent_session_header(session)$id %in% listed$id)
