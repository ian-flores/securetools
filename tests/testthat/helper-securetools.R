# --- Test helpers for securetools ---

#' Skip if securer is not installed
skip_if_no_securer <- function() {
  testthat::skip_if_not_installed("securer")
}

#' Skip if securer session cannot be created (e.g., CI without callr)
skip_if_no_session <- function() {
  skip_if_no_securer()
  testthat::skip_on_cran()
  sess <- tryCatch(
    securer::SecureSession$new(),
    error = function(e) NULL
  )
  if (is.null(sess)) {
    testthat::skip("Cannot create SecureSession")
  }
  sess$close()
}

#' Create a temporary directory inside a withr-managed temp dir
#' Returns the path (character).
make_test_dir <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  dir
}

