info <- rbebelm_backend_info()
tinytest::expect_true(is.list(info))
tinytest::expect_true("selected_backend" %in% names(info))
