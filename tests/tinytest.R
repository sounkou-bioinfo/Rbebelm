library(Rbebelm)
if (requireNamespace("tinytest", quietly = TRUE)) {
  test_dir <- system.file("tinytest", package = "Rbebelm")
  tinytest::run_test_file(file.path(test_dir, "test-backend.R"))
  tinytest::run_test_file(file.path(test_dir, "test-tools.R"))
  if (identical(Sys.getenv("RBEBELM_RUN_REAL_MODEL_TESTS"), "true")) {
    tinytest::run_test_file(file.path(test_dir, "test-real-model.R"))
  }
}
