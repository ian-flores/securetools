# --- End-to-end integration tests with SecureSession ---

test_that("calculator_tool works end-to-end via SecureSession", {
  skip_if_no_session()

  tool <- calculator_tool()
  session <- securer::SecureSession$new(tools = list(tool))
  on.exit(session$close())

  result <- session$execute('calculator(expression = "2 + 3 * 4")')
  expect_equal(result, 14)
})

test_that("calculator rejects unsafe code via SecureSession", {
  skip_if_no_session()

  tool <- calculator_tool()
  session <- securer::SecureSession$new(tools = list(tool))
  on.exit(session$close())

  expect_error(
    session$execute('calculator(expression = "system(\'whoami\')")'),
    "not allowed"
  )
})

test_that("data_profile_tool works end-to-end via SecureSession", {
  skip_if_no_session()
  # Data frames must serialize through JSON IPC, which converts them to

  # column-oriented lists. Use a tiny data frame (2 rows x 2 cols) to
  # keep serialization fast.
  tool <- data_profile_tool()
  session <- securer::SecureSession$new(tools = list(tool))
  on.exit(session$close())

  result <- session$execute(
    "data_profile(data = data.frame(x = 1:2, y = c('a', 'b'), stringsAsFactors = FALSE))",
    timeout = 60
  )
  expect_equal(result$nrow, 2)
  expect_equal(result$ncol, 2)
  expect_length(result$columns, 2)
})

test_that("multiple tools work together via SecureSession", {
  skip_if_no_session()

  calc <- calculator_tool()
  profile <- data_profile_tool()
  session <- securer::SecureSession$new(tools = list(calc, profile))
  on.exit(session$close())

  result <- session$execute('
    p <- data_profile(data = data.frame(a = 1:2, b = 3:4))
    calculator(expression = paste0(p$nrow, " + ", p$ncol))
  ', timeout = 60)
  expect_equal(result, 4)
})

test_that("r_help_tool works end-to-end via SecureSession", {
  skip_if_no_session()

  tool <- r_help_tool()
  session <- securer::SecureSession$new(tools = list(tool))
  on.exit(session$close())

  result <- session$execute('r_help(topic = "mean", package = "base")')
  expect_true(is.character(result))
  expect_true(nchar(result) > 0)
})
