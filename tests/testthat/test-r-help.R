test_that("r_help looks up base function", {
  tool <- r_help_tool()
  result <- tool@fn(topic = "mean", package = "base")
  expect_true(is.character(result))
  expect_true(nchar(result) > 0)
  expect_true(grepl("mean", result, ignore.case = TRUE))
})

test_that("r_help looks up stats function", {
  tool <- r_help_tool()
  result <- tool@fn(topic = "lm", package = "stats")
  expect_true(grepl("lm", result, ignore.case = TRUE))
})

test_that("r_help rejects package not in allow-list", {
  tool <- r_help_tool(allowed_packages = c("base"))
  expect_error(
    tool@fn(topic = "ggplot", package = "ggplot2"),
    "Package not allowed"
  )
})

test_that("r_help handles non-existent topic", {
  tool <- r_help_tool()
  expect_error(
    tool@fn(topic = "nonexistent_function_xyz", package = "base"),
    "No help found"
  )
})

test_that("r_help truncates long output", {
  tool <- r_help_tool(max_lines = 5)
  result <- tool@fn(topic = "lm", package = "stats")
  # Should end with truncation marker
  expect_true(grepl("truncated", result))
})

test_that("r_help rate limiting works", {
  tool <- r_help_tool(max_calls = 1)
  tool@fn(topic = "mean", package = "base")
  expect_error(tool@fn(topic = "sum", package = "base"), "Rate limit")
})

test_that("r_help_tool returns securer_tool object", {
  tool <- r_help_tool()
  expect_s3_class(tool, "securer::securer_tool")
  expect_equal(tool@name, "r_help")
})
