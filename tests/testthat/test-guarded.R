skip_if_not_installed("secureguard")
skip_if_not_installed("securer")

test_that("guarded_tool runs input guardrails and blocks on failure", {
  calc <- tool_calculator()

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
  # The wrapper must be a securer_tool-shaped object (same fn slot).
  expect_true(!is.null(guarded@fn))
  expect_equal(guarded@fn(expression = "1 + 1"), 2)
  expect_error(
    guarded@fn(expression = "forbidden + 1"),
    "input guardrail"
  )
})

test_that("guarded_tool runs output guardrails", {
  leaky <- securer::securer_tool(
    name        = "leaky",
    description = "Test tool that emits an AWS example key.",
    fn          = function() "AKIAIOSFODNN7EXAMPLE",
    args        = list()
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
