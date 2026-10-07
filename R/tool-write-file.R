# --- Write file tool ---

#' Create a file writing tool
#'
#' Returns a [securer::securer_tool()] that writes files into the folders
#' you allow, up to a size limit, without overwriting existing files unless
#' you say so.
#'
#' @param allowed_dirs Character vector of folders the tool can write to.
#' @param max_file_size The largest file the tool will write. Default
#'   `"10MB"`.
#' @param max_calls The most times the tool can be called. `NULL` means no
#'   limit.
#' @param overwrite Whether the tool may replace a file that already
#'   exists. Default `FALSE`.
#'
#' @details
#' The tool writes csv, json, txt, and rds files. It picks the format from
#' the file extension unless the caller passes `format`.
#'
#' The `content` argument is declared as `"list"` in the tool schema,
#' because arguments are sent between processes as JSON and most R objects
#' arrive as lists. Pass a data frame for csv and json, a character vector
#' for txt, and any R object for rds.
#'
#' The target's parent folder is resolved with [base::normalizePath()],
#' which follows symlinks, and must be inside one of `allowed_dirs`. The
#' data is written to a temporary file in the same folder first. If that
#' file is larger than `max_file_size`, nothing is written to the target.
#' Otherwise it is copied to the target, and the target's path is checked
#' again. If it now resolves outside `allowed_dirs`, the file is deleted
#' and the call fails.
#'
#' @return A `securer_tool` object.
#'
#' @family tool factories
#' @seealso \code{\link[securer]{securer_tool}}, \code{\link{tool_read_file}}
#'
#' @examples
#' \donttest{
#' tool <- tool_write_file(
#'   allowed_dirs = "/data/exports",
#'   max_file_size = "5MB",
#'   overwrite = FALSE
#' )
#' }
#' @export
tool_write_file <- function(allowed_dirs, max_file_size = "10MB",
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
      .do_write <- function() {
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
      }

      if (.trace_active()) {
        .with_span("tool.write_file", {
          result <- .do_write()
          .span_event("tool.result", list(tool = "write_file"))
          result
        })
      } else {
        .do_write()
      }
    },
    args = list(path = "character", content = "list", format = "character")
  )
}

