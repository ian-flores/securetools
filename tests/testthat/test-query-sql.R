test_that("query_sql queries all columns", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")

  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "users", data.frame(
    id = 1:3, name = c("Alice", "Bob", "Charlie"), age = c(30, 25, 35)
  ))

  tool <- tool_query_sql(con, allowed_tables = c("users"))
  result <- tool@fn(table = "users")

  expect_equal(nrow(result), 3)
  expect_true("name" %in% names(result))
})

test_that("query_sql selects specific columns", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")

  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "users", data.frame(
    id = 1:3, name = c("Alice", "Bob", "Charlie"), age = c(30, 25, 35)
  ))

  tool <- tool_query_sql(con, allowed_tables = c("users"))
  result <- tool@fn(table = "users", columns = "name, age")

  expect_equal(nrow(result), 3)
  expect_equal(names(result), c("name", "age"))
})

test_that("query_sql filters with parameterized query", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")

  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "users", data.frame(
    id = 1:3, name = c("Alice", "Bob", "Charlie"), age = c(30, 25, 35)
  ))

  tool <- tool_query_sql(con, allowed_tables = c("users"))
  result <- tool@fn(table = "users", filter_column = "name", filter_value = "Bob")

  expect_equal(nrow(result), 1)
  expect_equal(result$name, "Bob")
  expect_equal(result$age, 25)
})

test_that("query_sql rejects table not in allow-list", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")

  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "users", data.frame(id = 1:3, name = c("A", "B", "C")))
  DBI::dbWriteTable(con, "secrets", data.frame(id = 1, token = "s3cret"))

  tool <- tool_query_sql(con, allowed_tables = c("users"))
  expect_error(tool@fn(table = "secrets"), "not allowed")
})

test_that("query_sql rejects SQL injection in table name", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")

  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "users", data.frame(id = 1:3, name = c("A", "B", "C")))

  tool <- tool_query_sql(con, allowed_tables = c("users"))
  expect_error(tool@fn(table = "users; DROP TABLE users"), "Invalid table name")
})

test_that("query_sql rejects SQL injection in column name", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")

  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "users", data.frame(id = 1:3, name = c("A", "B", "C")))

  tool <- tool_query_sql(con, allowed_tables = c("users"))
  expect_error(
    tool@fn(table = "users", columns = "name; DROP TABLE users"),
    "Invalid column name"
  )
})

test_that("query_sql safely handles injection in filter_value via parameterized query", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")

  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "users", data.frame(
    id = 1:3, name = c("Alice", "Bob", "Charlie"), age = c(30, 25, 35)
  ))

  tool <- tool_query_sql(con, allowed_tables = c("users"))
  # Parameterized query treats this as a literal string value, not SQL
  result <- tool@fn(
    table = "users",
    filter_column = "name",
    filter_value = "'; DROP TABLE users; --"
  )

  # No rows match the injection string, so result should be empty
  expect_equal(nrow(result), 0)
  # Table should still exist
  expect_true(DBI::dbExistsTable(con, "users"))
})

test_that("query_sql respects max_rows", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")

  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "big", data.frame(
    id = 1:100, val = rnorm(100)
  ))

  tool <- tool_query_sql(con, allowed_tables = c("big"), max_rows = 5)
  result <- tool@fn(table = "big")

  expect_equal(nrow(result), 5)
})

test_that("query_sql rate limiting works", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")

  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "users", data.frame(id = 1, name = "Alice"))

  tool <- tool_query_sql(con, allowed_tables = c("users"), max_calls = 2)
  tool@fn(table = "users")
  tool@fn(table = "users")
  expect_error(tool@fn(table = "users"), "Rate limit")
})

test_that("tool_query_sql returns securer_tool object", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")

  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))

  tool <- tool_query_sql(con, allowed_tables = c("users"))
  expect_s3_class(tool, "securer::securer_tool")
  expect_equal(tool@name, "query_sql")
})

test_that("query_sql handles empty result set", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("RSQLite")
  con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  on.exit(DBI::dbDisconnect(con))
  DBI::dbWriteTable(con, "t", data.frame(id = 1:3, name = c("a", "b", "c")))
  tool <- tool_query_sql(conn = con, allowed_tables = "t")
  result <- tool@fn(table = "t", filter_column = "id", filter_value = "999")
  expect_equal(nrow(result), 0)
})
