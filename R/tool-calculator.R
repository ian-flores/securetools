# --- Calculator tool ---

# Allowed function names for calculator
.calc_allowed_fns <- c(
  "+", "-", "*", "/", "^", "%%", "%/%", "(",
  "sqrt", "abs", "log", "log2", "log10", "exp",
  "ceiling", "floor", "round", "trunc",
  "sin", "cos", "tan", "asin", "acos", "atan",
  "sum", "mean", "max", "min", "length",
  "c", "pi"
)

# Minimal eval environment built from the allowlist
.calc_eval_env <- local({
  fns <- mget(.calc_allowed_fns, envir = baseenv(), ifnotfound = list(NULL))
  fns <- fns[!vapply(fns, is.null, logical(1))]
  fns[["pi"]] <- pi
  fns[["T"]] <- TRUE
  fns[["F"]] <- FALSE
  fns[["TRUE"]] <- TRUE
  fns[["FALSE"]] <- FALSE
  fns[["Inf"]] <- Inf
  fns[["NaN"]] <- NaN
  fns[["NA"]] <- NA
  list2env(fns, parent = emptyenv())
})

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
    if (name %in% .calc_allowed_fns) {
      return(invisible(TRUE))
    }
    cli_abort("Variable access not allowed in calculator: {.val {name}}")
  }

  if (is.call(expr)) {
    fn_name <- as.character(expr[[1]])
    if (!fn_name %in% .calc_allowed_fns) {
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
#'
#' @details
#' The calculator tool evaluates mathematical expressions in a restricted
#' environment. Only the following functions and operators are allowed:
#'
#' \itemize{
#'   \item **Arithmetic**: `+`, `-`, `*`, `/`, `^`, `%%`, `%/%`
#'   \item **Math**: `sqrt`, `abs`, `log`, `log2`, `log10`, `exp`,
#'     `ceiling`, `floor`, `round`, `trunc`
#'   \item **Trigonometry**: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`
#'   \item **Aggregation**: `sum`, `mean`, `max`, `min`, `length`
#'   \item **Utilities**: `c`, `pi`
#' }
#'
#' Expressions are first parsed and validated via an AST walk that rejects
#' any function call or symbol not on the allowlist. Evaluation then occurs
#' in a minimal environment containing only the allowed functions, with
#' `emptyenv()` as its parent to prevent access to other R functionality.
#'
#' @family tool factories
#' @seealso \code{\link[securer]{securer_tool}}
#'
#' @examples
#' \donttest{
#' calc <- calculator_tool()
#' # Basic arithmetic
#' calc@fn(expression = "2 + 3 * 4")
#'
#' # Math functions
#' calc@fn(expression = "sqrt(144) + log(exp(1))")
#'
#' # With rate limiting
#' calc <- calculator_tool(max_calls = 100)
#' }
#'
#' @export
calculator_tool <- function(max_calls = NULL) {
  if (!is.null(max_calls) && (!is.numeric(max_calls) || length(max_calls) != 1L || max_calls < 1L)) {
    cli_abort("{.arg max_calls} must be NULL or a positive number.")
  }

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

      # Safe to evaluate in minimal environment
      eval(parsed, envir = .calc_eval_env)
    },
    args = list(expression = "character")
  )
}
