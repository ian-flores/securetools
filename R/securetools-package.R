#' securetools: ready-made tools with limits for securer
#'
#' Ready-made tools for LLM agents that run in a \pkg{securer} session.
#' Each `tool_*()` function returns a [securer::securer_tool()] with limits
#' you set when you create it, such as allowed folders, allowed tables,
#' allowed domains, size caps, and call limits.
#'
#' @seealso [securer::securer_tool()] for the underlying tool constructor.
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom R6 R6Class
#' @importFrom rlang abort caller_env
#' @importFrom cli cli_abort cli_warn
#' @importFrom utils getFromNamespace
## usethis namespace: end
NULL

# Tracer name used for OpenTelemetry spans (see R/utils-trace.R).
# Not exported.
otel_tracer_name <- "com.github.ian-flores.securetools"
