info <- rbebelm_backend_info()
expect_true(is.list(info))
expect_true("selected_backend" %in% names(info))
