#' securetools: Security-Hardened Tool Definitions for securer
#'
#' Provides pre-built, security-hardened tool definitions for use with
#' the \pkg{securer} package. Each tool factory returns a
#' [securer::securer_tool()] object with built-in security constraints
#' such as path validation, allow-lists, rate limiting, and parameterized
#' queries.
#'
#' @seealso [securer::securer_tool()] for the underlying tool constructor.
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom R6 R6Class
#' @importFrom rlang abort caller_env
#' @importFrom cli cli_abort cli_warn
## usethis namespace: end
NULL
