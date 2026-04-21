skip_if_not_installed("secureguard")
skip_if_not_installed("securer")

test_that("guarded_tool runs input guardrails and blocks on failure", {
  calc <- tool_calculator()

  # A cheap synthetic guardrail that blocks the literal string "forbidden".
  deny <- secureguard::new_guardrail(
    name = "deny-forbidden",
    type = "input",
    check_fn = function(code) {
      if (grepl("forbidden", code, fixed = TRUE)) {
        secureguard::guardrail_result(
          pass = FALSE, reason = "literal forbidden token"
        )
      } else {
        secureguard::guardrail_result(pass = TRUE)
      }
    }
  )

  guarded <- guarded_tool(calc, input_guards = list(deny))
  expect_s4_class(guarded, "securer_tool_class") |> suppressWarnings()
  # Happy path still evaluates.
  expect_equal(guarded@fn(expression = "1 + 1"), 2)
  # Blocked path raises an informative error.
  expect_error(
    guarded@fn(expression = "forbidden + 1"),
    "input guardrail"
  )
})

test_that("guarded_tool runs output guardrails", {
  # A tool that returns a fixed secret-like string.
  leaky <- securer::securer_tool(
    name = "leaky",
    fn   = function() "AKIAIOSFODNN7EXAMPLE",
    args = list()
  )
  block_secrets <- secureguard::guard_output_secrets(action = "block")

  guarded <- guarded_tool(leaky, output_guards = list(block_secrets))
  expect_error(guarded@fn(), "output guardrail")
})

test_that("with_guards is an alias of guarded_tool", {
  calc <- tool_calculator()
  g <- with_guards(calc)
  expect_equal(g@fn(expression = "3 * 4"), 12)
})

test_that("guarded_tool errors without secureguard hint", {
  # Simulate secureguard missing by masking requireNamespace.
  local_mocked_bindings(
    requireNamespace = function(pkg, quietly = TRUE, ...) {
      if (identical(pkg, "secureguard")) FALSE else TRUE
    }
  )
  expect_error(guarded_tool(tool_calculator()), "secureguard")
})
