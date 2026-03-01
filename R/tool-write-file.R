# --- Write file tool ---

#' Create a file writing tool
#'
#' Returns a [securer::securer_tool()] that writes data to files in
#' specified directories with size limits and overwrite protection.
#'
#' @param allowed_dirs Character vector of directories the tool can write to.
#' @param max_file_size Max output file size. Default `"10MB"`.
#' @param max_calls Maximum invocations. `NULL` means unlimited.
#' @param overwrite Whether to allow overwriting existing files. Default `FALSE`.
#'
#' @details
#' The `content` argument type is declared as `"list"` in the tool schema
#' because the IPC serialization layer (JSON) converts most R objects to
#' lists. In practice, callers should pass:
#' \itemize{
#'   \item A \code{data.frame} for CSV and JSON formats
#'   \item A character vector for TXT format
#'   \item Any R object for RDS format
#' }
#'
#' Supported formats: csv, json, txt, rds. Format is auto-detected from
#' the file extension, or can be specified explicitly.
#'
#' Security constraints:
#' \itemize{
#'   \item \strong{Atomic writes}: Data is written to a temp file first,
#'     validated for size, then moved to the target path.
#'   \item \strong{Overwrite protection}: By default, existing files cannot
#'     be overwritten (controlled by the `overwrite` parameter).
#'   \item \strong{Symlink resolution}: Target paths are resolved via
#'     [base::normalizePath()] to prevent symlink-based directory escapes.
#'   \item \strong{Size limits}: Written files exceeding `max_file_size`
#'     are rejected before being moved to the target.
#' }
#'
#' @return A `securer_tool` object.
#'
#' @family tool factories
#' @seealso \code{\link[securer]{securer_tool}}, \code{\link{read_file_tool}}
#'
#' @examples
#' \donttest{
#' tool <- write_file_tool(
#'   allowed_dirs = "/data/exports",
#'   max_file_size = "5MB",
#'   overwrite = FALSE
#' )
#' }
#' @export
write_file_tool <- function(allowed_dirs, max_file_size = "10MB",
                            max_calls = NULL, overwrite = FALSE) {
  # Factory argument validation
  if (!is.character(allowed_dirs) || length(allowed_dirs) == 0L) {
    cli_abort("{.arg allowed_dirs} must be a non-empty character vector.")
  }
  if (!is.null(max_calls) && (!is.numeric(max_calls) || length(max_calls) != 1L || max_calls < 1L)) {
    cli_abort("{.arg max_calls} must be NULL or a positive number.")
  }

  max_bytes <- parse_size(max_file_size)
  limiter <- new_rate_limiter(max_calls)

  securer::securer_tool(
    name = "write_file",
    description = paste(
      "Write data to a file in allowed directories.",
      "Supports csv, json, txt, rds formats."
    ),
    fn = function(path, content, format = "auto") {
      check_rate_limit(limiter)

      # Validate the target path (parent dir must be in allowed_dirs)
      resolved <- validate_path(path, allowed_dirs, must_exist = FALSE)

      # Overwrite protection
      if (!overwrite && file.exists(resolved)) {
        cli_abort("File already exists and overwrite is disabled: {.path {path}}")
      }

      # Auto-detect format from extension
      # NOTE: Duplicates logic from detect_format() in tool-read-file.R.
      # Write supports a subset of read formats (csv, json, txt, rds).
      if (identical(format, "auto")) {
        ext <- tolower(tools::file_ext(path))
        format <- switch(ext,
          csv = "csv",
          json = "json",
          txt = , text = "txt",
          rds = "rds",
          cli_abort("Cannot auto-detect write format for extension: {.val {ext}}")
        )
      }

      # Write to temp file first, check size, then move
      tmp <- tempfile(tmpdir = dirname(resolved))
      on.exit(unlink(tmp), add = TRUE)

      switch(format,
        csv = {
          if (is.data.frame(content)) {
            utils::write.csv(content, tmp, row.names = FALSE)
          } else {
            cli_abort("CSV format requires a data frame as content.")
          }
        },
        json = {
          rlang::check_installed("jsonlite", reason = "to write JSON files")
          writeLines(jsonlite::toJSON(content, auto_unbox = TRUE, pretty = TRUE), tmp)
        },
        txt = {
          if (is.character(content)) {
            writeLines(content, tmp)
          } else {
            writeLines(as.character(content), tmp)
          }
        },
        rds = {
          saveRDS(content, tmp)
        },
        cli_abort("Unsupported write format: {.val {format}}")
      )

      # Check size of written file
      validate_file_size(tmp, max_bytes)

      # Move to target
      file.copy(tmp, resolved, overwrite = TRUE)

      # Re-validate after write to catch symlink TOCTOU attacks
      validate_written_path(resolved, allowed_dirs)

      invisible(list(path = resolved, size = file.info(resolved)$size, format = format))
    },
    args = list(path = "character", content = "list", format = "character")
  )
}
