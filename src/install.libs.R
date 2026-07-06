main_files <- Sys.glob(paste0("*", SHLIB_EXT))
backend_files <- c(
  Sys.glob(file.path("rbebelm-backends", "*.so")),
  Sys.glob(file.path("rbebelm-backends", "*.dylib")),
  Sys.glob(file.path("rbebelm-backends", "*.dll"))
)

lib_dest <- file.path(R_PACKAGE_DIR, paste0("libs", R_ARCH))
dir.create(lib_dest, recursive = TRUE, showWarnings = FALSE)
if (length(main_files)) {
  file.copy(main_files, lib_dest, overwrite = TRUE)
  if (!WINDOWS) {
    Sys.chmod(file.path(lib_dest, basename(main_files)), mode = "0755")
  }
}

backend_dest <- file.path(R_PACKAGE_DIR, paste0("backends", R_ARCH))
dir.create(backend_dest, recursive = TRUE, showWarnings = FALSE)
if (length(backend_files)) {
  file.copy(backend_files, backend_dest, overwrite = TRUE)
  if (!WINDOWS) {
    Sys.chmod(file.path(backend_dest, basename(backend_files)), mode = "0755")
  }
}
