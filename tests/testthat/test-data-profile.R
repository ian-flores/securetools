test_that("data_profile profiles iris dataset", {
  tool <- data_profile_tool()
  result <- tool@fn(data = iris)
  expect_equal(result$nrow, 150)
  expect_equal(result$ncol, 5)
  expect_false(result$sampled)
  expect_length(result$columns, 5)

  # Check numeric column has stats
  sl <- result$columns[[1]] # Sepal.Length
  expect_equal(sl$name, "Sepal.Length")
  expect_true(!is.null(sl$min))
  expect_true(!is.null(sl$max))
  expect_true(!is.null(sl$mean))
  expect_true(!is.null(sl$sd))
})

test_that("data_profile handles NA values", {
  df <- data.frame(x = c(1, 2, NA, 4), y = c("a", NA, "b", "b"))
  tool <- data_profile_tool()
  result <- tool@fn(data = df)

  x_col <- result$columns[[1]]
  expect_equal(x_col$n_missing, 1)

  y_col <- result$columns[[2]]
  expect_equal(y_col$n_missing, 1)
})

test_that("data_profile handles character columns", {
  df <- data.frame(
    x = c("a", "b", "b", "c", "c", "c"),
    stringsAsFactors = FALSE
  )
  tool <- data_profile_tool()
  result <- tool@fn(data = df)

  col <- result$columns[[1]]
  expect_equal(col$n_unique, 3)
  expect_true(!is.null(col$top_values))
})

test_that("data_profile samples large data frames", {
  df <- data.frame(x = seq_len(200))
  tool <- data_profile_tool(max_rows = 50)
  result <- tool@fn(data = df)

  expect_equal(result$nrow, 200) # original nrow
  expect_true(result$sampled)
  expect_equal(result$sample_size, 50)
})

test_that("data_profile handles empty data frame", {
  df <- data.frame(x = numeric(0), y = character(0))
  tool <- data_profile_tool()
  result <- tool@fn(data = df)

  expect_equal(result$nrow, 0)
  expect_equal(result$ncol, 2)
})

test_that("data_profile handles single column", {
  df <- data.frame(x = 1:5)
  tool <- data_profile_tool()
  result <- tool@fn(data = df)

  expect_equal(result$ncol, 1)
  expect_length(result$columns, 1)
})

test_that("data_profile rate limiting works", {
  tool <- data_profile_tool(max_calls = 1)
  tool@fn(data = iris)
  expect_error(tool@fn(data = iris), "Rate limit")
})

test_that("data_profile_tool returns securer_tool object", {
  tool <- data_profile_tool()
  expect_s3_class(tool, "securer::securer_tool")
  expect_equal(tool@name, "data_profile")
})

test_that("data_profile coerces lists to data frames", {
  tool <- data_profile_tool()
  # Named list (like JSON-deserialized data frame) should work
  result <- tool@fn(data = list(x = c(1, 2, 3), y = c("a", "b", "c")))
  expect_equal(result$nrow, 3)
  expect_equal(result$ncol, 2)
})

test_that("data_profile rejects non-list input", {
  tool <- data_profile_tool()
  expect_error(tool@fn(data = "not a data frame"), "data frame")
})

test_that("data_profile handles logical columns", {
  tool <- data_profile_tool()
  result <- tool@fn(data = data.frame(x = c(TRUE, FALSE, NA)))
  expect_equal(result$columns[[1]]$n_missing, 1)
})

test_that("data_profile handles all-NA column", {
  tool <- data_profile_tool()
  result <- tool@fn(data = data.frame(x = c(NA_real_, NA_real_, NA_real_)))
  expect_equal(result$columns[[1]]$n_missing, 3)
})
