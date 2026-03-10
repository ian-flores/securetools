# --- R help documentation tool ---

#' Create an R help documentation tool
#'
#' Returns a [securer::securer_tool()] that looks up R function
#' documentation from a set of allowed packages.
#'
#' @param allowed_packages Character vector of packages the tool can look up
#'   documentation from. Default includes base R packages.
#' @param max_lines Maximum lines of help text to return. Default 100.
#' @param max_calls Maximum invocations. `NULL` means unlimited.
#'
#' @details
#' The tool restricts documentation lookup to the packages specified
#' in `allowed_packages`. Both topic name and package name must be
#' provided; the package must be in the allow-list.
#'
#' Help text is rendered as plain text via [tools::Rd2txt()] and
#' truncated to `max_lines` lines.
#'
#' @return A `securer_tool` object.
#'
#' @family tool factories
#' @seealso \code{\link[securer]{securer_tool}}
#'
#' @examples
#' \donttest{
#' tool <- r_help_tool(
#'   allowed_packages = c("base", "stats", "utils"),
#'   max_lines = 200
#' )
#' }
#' @export
r_help_tool <- function(allowed_packages = c("base", "stats", "utils",
                                              "methods", "grDevices",
                                              "graphics", "datasets"),
                        max_lines = 100, max_calls = NULL) {
  # Factory argument validation
  if (!is.character(allowed_packages) || length(allowed_packages) == 0L) {
    cli_abort("{.arg allowed_packages} must be a non-empty character vector.")
  }
  if (!is.null(max_calls) && (!is.numeric(max_calls) || length(max_calls) != 1L || max_calls < 1L)) {
    cli_abort("{.arg max_calls} must be NULL or a positive number.")
  }

  limiter <- new_rate_limiter(max_calls)

  securer::securer_tool(
    name = "r_help",
    description = "Look up R function documentation from allowed packages.",
    fn = function(topic, package = "base") {
      .do_help <- function() {
        check_rate_limit(limiter)

        if (!package %in% allowed_packages) {
          cli_abort("Package not allowed: {.val {package}}. Allowed: {.val {allowed_packages}}")
        }

        # Look up help
        help_obj <- tryCatch(
          utils::help(topic, package = (package)),
          error = function(e) NULL
        )

        if (is.null(help_obj) || length(help_obj) == 0L) {
          cli_abort("No help found for {.fn {topic}} in package {.pkg {package}}")
        }

        # NOTE: Accesses unexported utils function .getHelpFile.
        # This may break in future R versions if the internal API changes.
        get_help_file <- getFromNamespace(".getHelpFile", "utils")
        help_file <- get_help_file(help_obj)
        txt <- utils::capture.output(
          tools::Rd2txt(help_file, out = stdout(), package = package)
        )

        # Truncate to max_lines
        if (length(txt) > max_lines) {
          txt <- c(txt[seq_len(max_lines)], "... [truncated]")
        }

        paste(txt, collapse = "\n")
      }

      if (.trace_active()) {
        securetrace::with_span("tool.r_help", type = "tool", {
          result <- .do_help()
          .span_event("tool.result", list(tool = "r_help"))
          result
        })
      } else {
        .do_help()
      }
    },
    args = list(topic = "character", package = "character")
  )
}
