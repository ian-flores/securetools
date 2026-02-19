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
#' @return A `securer_tool` object.
#' @export
r_help_tool <- function(allowed_packages = c("base", "stats", "utils",
                                              "methods", "grDevices",
                                              "graphics", "datasets"),
                        max_lines = 100, max_calls = NULL) {
  limiter <- new_rate_limiter(max_calls)

  securer::securer_tool(
    name = "r_help",
    description = "Look up R function documentation from allowed packages.",
    fn = function(topic, package = "base") {
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

      # Render help text -- .getHelpFile is not exported, access via namespace
      get_help_file <- get(".getHelpFile", envir = asNamespace("utils"))
      help_file <- get_help_file(help_obj)
      txt <- utils::capture.output(
        tools::Rd2txt(help_file, out = stdout(), package = package)
      )

      # Truncate to max_lines
      if (length(txt) > max_lines) {
        txt <- c(txt[seq_len(max_lines)], "... [truncated]")
      }

      paste(txt, collapse = "\n")
    },
    args = list(topic = "character", package = "character")
  )
}
