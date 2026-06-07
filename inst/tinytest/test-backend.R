info <- rbebelm_backend_info()
expect_true(is.list(info))
expect_true("selected_backend" %in% names(info))

cpu <- rbebelm_cpuid_info()
expect_true(inherits(cpu, "rbebelmCpuidInfo"))
expect_true(is.list(cpu))
expect_true(grepl("Rbebelm CPU features", paste(capture.output(print(cpu)), collapse = "\n")))

features <- rbebelm_backend_features()
expect_true(inherits(features, "rbebelmBackendFeatures"))
expect_true(is.list(features))
expect_true(grepl("Rbebelm backend features", paste(capture.output(print(features)), collapse = "\n")))
