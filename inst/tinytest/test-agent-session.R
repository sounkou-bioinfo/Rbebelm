library(Rbebelm)

tmp <- tempfile("rbebelm-session-")
dir.create(tmp)

session <- bebel_session_create(cwd = tmp, session_dir = tmp, name = "demo")
expect_true(inherits(session, "bebelSession"))
expect_true(file.exists(bebel_session_file(session)))
expect_equal(bebel_session_header(session)$version, 3L)

u1 <- bebel_session_append_message(session, "user", "hello", source = "test")
a1 <- bebel_session_append_message(session, "assistant", list(list(type = "text", text = "hi")), provider = "fake", model = "fake-model", stopReason = "stop")
expect_true(inherits(bebel_session_leaf_id(session), "bebelSessionLeafId"))
expect_equal(as.character(bebel_session_leaf_id(session)), a1)
expect_equal(length(bebel_session_entries(session)), 3L)

bebel_session_append_custom(session, "counter", list(n = 1L))
bebel_session_append_custom_message(session, "context", "extra context", display = FALSE)
ctx <- bebel_session_context(session)
expect_true(length(ctx$messages) >= 3L)
expect_true(any(vapply(ctx$messages, function(x) identical(x$role, "custom"), logical(1))))
expect_equal(ctx$model$modelId, "fake-model")

bebel_session_checkout(session, u1)
u2 <- bebel_session_append_message(session, "user", "branch")
expect_equal(as.character(bebel_session_leaf_id(session)), u2)
branch <- bebel_session_branch(session)
branch_ids <- vapply(branch, `[[`, character(1), "id")
expect_equal(tail(branch_ids, 2L), c(u1, u2))

tree <- bebel_session_tree(session)
expect_true(length(tree) >= 1L)
expect_true(length(tree[[1L]]$children) >= 1L)

bebel_session_append_label(session, u1, "checkpoint")
expect_true(any(vapply(bebel_session_entries(session), function(x) identical(x$type, "label"), logical(1))))

opened <- bebel_session_open(bebel_session_file(session))
expect_equal(bebel_session_header(opened)$id, bebel_session_header(session)$id)
expect_equal(length(bebel_session_entries(opened)), length(bebel_session_entries(session)))

forked <- bebel_session_fork(bebel_session_file(session), cwd = tmp, session_dir = tmp)
expect_true(!identical(bebel_session_header(forked)$id, bebel_session_header(session)$id))
expect_equal(normalizePath(bebel_session_header(forked)$parentSession, winslash = "/"), normalizePath(bebel_session_file(session), winslash = "/"))
expect_equal(length(bebel_session_entries(forked)), length(bebel_session_entries(session)))

cloned <- bebel_session_clone_branch(session, leaf_id = u2, session_dir = tmp)
expect_true(!identical(bebel_session_header(cloned)$id, bebel_session_header(session)$id))
cloned_ids <- vapply(bebel_session_entries(cloned), `[[`, character(1), "id")
expect_true(u2 %in% cloned_ids)
expect_false(a1 %in% cloned_ids)

listed <- bebel_session_list(session_dir = tmp)
expect_true(nrow(listed) >= 2L)
expect_true(bebel_session_header(session)$id %in% listed$id)
