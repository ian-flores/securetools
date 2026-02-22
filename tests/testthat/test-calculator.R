test_that("calculator evaluates basic arithmetic", {
  tool <- calculator_tool()
  expect_equal(tool@fn(expression = "2 + 3"), 5)
  expect_equal(tool@fn(expression = "10 * 3 - 5"), 25)
  expect_equal(tool@fn(expression = "2 ^ 10"), 1024)
  expect_equal(tool@fn(expression = "10 %% 3"), 1)
})

test_that("calculator evaluates math functions", {
  tool <- calculator_tool()
  expect_equal(tool@fn(expression = "sqrt(16)"), 4)
  expect_equal(tool@fn(expression = "abs(-5)"), 5)
  expect_equal(tool@fn(expression = "log(exp(1))"), 1)
  expect_equal(tool@fn(expression = "round(3.14159, 2)"), 3.14)
})

test_that("calculator evaluates aggregation functions", {
  tool <- calculator_tool()
  expect_equal(tool@fn(expression = "mean(c(1, 2, 3))"), 2)
  expect_equal(tool@fn(expression = "sum(c(10, 20, 30))"), 60)
  expect_equal(tool@fn(expression = "max(c(1, 5, 3))"), 5)
})

test_that("calculator allows pi", {
  tool <- calculator_tool()
  expect_equal(tool@fn(expression = "pi"), pi)
  expect_equal(tool@fn(expression = "2 * pi"), 2 * pi)
})

test_that("calculator rejects variable access", {
  tool <- calculator_tool()
  expect_error(tool@fn(expression = "x + 1"), "Variable access not allowed")
})

test_that("calculator rejects arbitrary function calls", {
  tool <- calculator_tool()
  expect_error(tool@fn(expression = "system('whoami')"), "not allowed")
  expect_error(tool@fn(expression = "Sys.getenv('HOME')"), "not allowed")
  expect_error(tool@fn(expression = ".Internal(inspect(1))"), "not allowed")
})

test_that("calculator rejects assignment", {
  tool <- calculator_tool()
  expect_error(tool@fn(expression = "x <- 1"), "not allowed")
})

test_that("calculator rejects multiple expressions", {
  tool <- calculator_tool()
  expect_error(tool@fn(expression = "1; system('whoami')"), "single expression")
})

test_that("calculator rejects invalid syntax", {
  tool <- calculator_tool()
  expect_error(tool@fn(expression = "2 +"), "Invalid expression")
})

test_that("calculator rate limiting works", {
  tool <- calculator_tool(max_calls = 2)
  tool@fn(expression = "1 + 1")
  tool@fn(expression = "2 + 2")
  expect_error(tool@fn(expression = "3 + 3"), "Rate limit")
})

test_that("calculator handles empty expression", {
  tool <- calculator_tool()
  expect_error(tool@fn(expression = ""))
})

test_that("calculator handles Inf and NaN", {
  tool <- calculator_tool()
  expect_equal(tool@fn(expression = "1/0"), Inf)
  expect_true(is.nan(tool@fn(expression = "0/0")))
})

test_that("calculator rejects backtick-quoted dangerous functions", {
  tool <- calculator_tool()
  expect_error(tool@fn(expression = "`system`('whoami')"), "[Nn]ot allowed")
})

test_that("calculator_tool returns securer_tool object", {
  tool <- calculator_tool()
  expect_s3_class(tool, "securer::securer_tool")
  expect_equal(tool@name, "calculator")
})
