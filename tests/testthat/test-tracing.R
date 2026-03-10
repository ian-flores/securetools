test_that("calculator_tool emits span when trace active", {
  skip_if_not_installed("securetrace")

  calc <- calculator_tool()

  result <- securetrace::with_trace("test-calc", {
    calc@fn(expression = "2 + 3")
  })

  expect_equal(result, 5)
})

test_that("tools work without securetrace trace", {
  calc <- calculator_tool()
  result <- calc@fn(expression = "2 + 3")
  expect_equal(result, 5)
})
