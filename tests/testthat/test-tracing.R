test_that("tool_calculator emits span when trace active", {
  skip_if_not_installed("securetrace")

  calc <- tool_calculator()

  result <- securetrace::with_trace("test-calc", {
    calc@fn(expression = "2 + 3")
  })

  expect_equal(result, 5)
})

test_that("tools work without securetrace trace", {
  calc <- tool_calculator()
  result <- calc@fn(expression = "2 + 3")
  expect_equal(result, 5)
})
