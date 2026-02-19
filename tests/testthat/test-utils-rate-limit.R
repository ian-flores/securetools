test_that("NULL max_calls returns NULL", {
  expect_null(new_rate_limiter(max_calls = NULL))
  expect_null(new_rate_limiter(max_calls = NULL, window_secs = 10))
})

test_that("lifetime limiting enforces max_calls", {
  lim <- new_rate_limiter(max_calls = 3)

  expect_s3_class(lim, "securetools_rate_limiter")

  # First 3 calls succeed

  expect_true(lim$check())
  expect_true(lim$check())
  expect_true(lim$check())

  # 4th call fails
  expect_error(lim$check(), "Rate limit exceeded")
})

test_that("window-based limiting expires old calls", {
  lim <- new_rate_limiter(max_calls = 2, window_secs = 1)

  # Fill the window
  lim$check()
  lim$check()

  # 3rd call should fail immediately
  expect_error(lim$check(), "Rate limit exceeded")

  # Wait for the 1-second rate-limit window to expire. We sleep slightly

  # longer than the window (1.01s) to avoid flaky failures from timer
  # granularity on slow CI runners.
  Sys.sleep(1.01)

  # Now calls should succeed again
  expect_true(lim$check())
})

test_that("check_rate_limit with NULL limiter does nothing", {
  expect_invisible(check_rate_limit(NULL))
  expect_null(check_rate_limit(NULL))
})

test_that("check_rate_limit with active limiter delegates to $check()", {
  lim <- new_rate_limiter(max_calls = 1)

  # First call succeeds
  check_rate_limit(lim)

  # Second call fails via limiter

  expect_error(check_rate_limit(lim), "Rate limit exceeded")
})
