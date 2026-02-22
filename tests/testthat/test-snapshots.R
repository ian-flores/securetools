test_that("path traversal error message", {
  dir <- withr::local_tempdir()
  expect_snapshot(error = TRUE, transform = function(x) {
    gsub(dir, "<TMPDIR>", x, fixed = TRUE)
  }, {
    validate_path(file.path(dir, "..", "etc", "passwd"), allowed_dirs = dir)
  })
})

test_that("empty path error message", {
  dir <- withr::local_tempdir()
  expect_snapshot(error = TRUE, {
    validate_path("", allowed_dirs = dir)
  })
})

test_that("rate limit error message", {
  limiter <- new_rate_limiter(max_calls = 1)
  check_rate_limit(limiter)
  expect_snapshot(error = TRUE, {
    check_rate_limit(limiter)
  })
})

test_that("calculator rejection message", {
  tool <- calculator_tool()
  expect_snapshot(error = TRUE, {
    tool@fn(expression = "system('whoami')")
  })
})
