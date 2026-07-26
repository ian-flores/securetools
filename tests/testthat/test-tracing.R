test_that("tool_calculator emits an otel span when tracing is enabled", {
  skip_if_not_installed("otel")
  skip_if_not_installed("otelsdk")

  calc <- tool_calculator()

  rec <- otelsdk::with_otel_record({
    calc@fn(expression = "2 + 3")
  })

  expect_equal(rec$value, 5)
  expect_true("tool.calculator" %in% names(rec$traces))

  span <- rec$traces[["tool.calculator"]]
  expect_equal(span$name, "tool.calculator")

  event_names <- vapply(span$events, function(e) e$name, character(1))
  expect_true("tool.result" %in% event_names)

  result_event <- span$events[[match("tool.result", event_names)]]
  expect_equal(result_event$attributes$tool, "calculator")
})

test_that("multiple tools emit distinct spans in one recording", {
  skip_if_not_installed("otel")
  skip_if_not_installed("otelsdk")

  tmp <- withr::local_tempdir()
  writeLines("x,y\n1,2\n3,4", file.path(tmp, "data.csv"))

  calc <- tool_calculator()
  reader <- tool_read_file(allowed_dirs = tmp)

  rec <- otelsdk::with_otel_record({
    calc@fn(expression = "1 + 1")
    reader@fn(path = file.path(tmp, "data.csv"), format = "csv")
  })

  expect_true(all(
    c("tool.calculator", "tool.read_file") %in% names(rec$traces)
  ))
})

test_that("tools work with tracing disabled (otel inactive)", {
  # No tracer provider is set up here, so .trace_active() is FALSE and
  # tools must run through the untraced path.
  expect_false(.trace_active())

  calc <- tool_calculator()
  result <- calc@fn(expression = "2 + 3")
  expect_equal(result, 5)
})

test_that(".span_event is a no-op when tracing is disabled", {
  expect_no_error(.span_event("tool.result", list(tool = "calculator")))
  expect_invisible(.span_event("tool.result"))
})
