# --- Calculator tool ---

# Allowed function names for calculator
calc_allowed_fns <- c(
  "+", "-", "*", "/", "^", "%%", "%/%", "(",
  "sqrt", "abs", "log", "log2", "log10", "exp",
  "ceiling", "floor", "round", "trunc",
  "sin", "cos", "tan", "asin", "acos", "atan",
  "sum", "mean", "max", "min", "length",
  "c", "pi"
)

#' Validate a calculator AST node recursively
#'
#' Walks the parse tree and rejects anything outside the allowed
#' arithmetic/math function set.
#'
#' @param expr A language object from `parse()`.
#' @return `invisible(TRUE)` on success; errors otherwise.
#' @noRd
validate_calc_ast <- function(expr) {
  if (is.numeric(expr)) {
    return(invisible(TRUE))
  }

  if (is.symbol(expr)) {
    name <- as.character(expr)
    if (name %in% calc_allowed_fns) {
      return(invisible(TRUE))
    }
    cli_abort("Variable access not allowed in calculator: {.val {name}}")
  }

  if (is.call(expr)) {
    fn_name <- as.character(expr[[1]])
    if (!fn_name %in% calc_allowed_fns) {
      cli_abort("Function not allowed in calculator: {.fn {fn_name}}")
    }
    # Recursively validate all arguments
    for (i in seq_along(expr)[-1]) {
      validate_calc_ast(expr[[i]])
    }
    return(invisible(TRUE))
  }

  cli_abort("Unsupported expression type in calculator.")
}

#' Create a calculator tool
#'
#' Returns a [securer::securer_tool()] that evaluates mathematical
#' expressions safely via AST validation.
#'
#' @param max_calls Maximum number of invocations allowed. `NULL` (default)
#'   means unlimited.
#' @return A `securer_tool` object.
#' @export
calculator_tool <- function(max_calls = NULL) {
  limiter <- new_rate_limiter(max_calls)

  securer::securer_tool(
    name = "calculator",
    description = paste(
      "Evaluate a mathematical expression safely.",
      "Only arithmetic, math functions, and numeric literals are allowed."
    ),
    fn = function(expression) {
      check_rate_limit(limiter)

      # Parse the expression
      parsed <- tryCatch(
        parse(text = expression),
        error = function(e) cli_abort("Invalid expression: {e$message}")
      )

      # Reject multiple expressions (e.g. "1; system('whoami')")
      if (length(parsed) != 1L) {
        cli_abort(
          "Expression must be a single expression, got {length(parsed)}."
        )
      }

      # AST walk to validate
      validate_calc_ast(parsed[[1]])

      # Safe to evaluate
      eval(parsed, envir = baseenv())
    },
    args = list(expression = "character")
  )
}
