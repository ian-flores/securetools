# --- File reading tool ---

#' Create a file reading tool
#'
#' Returns a [securer::securer_tool()] that reads files from the folders
#' you allow, up to a size limit.
#'
#' @param allowed_dirs Character vector of folders the tool can read from.
#' @param max_file_size The largest file the tool will read. Either a
#'   number of bytes or a string like `"10MB"`. Default `"50MB"`.
#' @param max_rows The most rows to read from csv and xlsx files. Default
#'   10000.
#' @param max_calls The most times the tool can be called. `NULL` means no
#'   limit.
#'
#' @details
#' The tool reads csv, json, txt, xlsx, parquet, and rds files. It picks
#' the format from the file extension unless the caller passes `format`.
#'
#' Every path is resolved with [base::normalizePath()], which follows
#' symlinks, and must then be inside one of `allowed_dirs`. A symlink that
#' points outside those folders is rejected.
#'
#' Files larger than `max_file_size` are rejected before they are read.
#' csv and xlsx files are cut off at `max_rows` rows.
#'
#' Reading an rds file can run code stored in the object, so rds files are
#' read in a separate R process with \pkg{callr}.
#'
#' @return A `securer_tool` object.
#'
#' @family tool factories
#' @seealso \code{\link[securer]{securer_tool}}
#'
#' @examples
#' \donttest{
#' tool <- tool_read_file(
#'   allowed_dirs = c("/data/reports", "/data/exports"),
#'   max_file_size = "10MB",
#'   max_rows = 5000
#' )
#' }
#' @export
tool_read_file <- function(allowed_dirs, max_file_size = "50MB", max_rows = 10000,
                           max_calls = NULL) {
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
    name = "read_file",
    description = paste(
      "Read a file from allowed directories.",
      "Supports csv, json, txt, xlsx, parquet, rds formats."
    ),
    fn = function(path, format = "auto") {
      .do_read <- function() {
        check_rate_limit(limiter)

        resolved <- validate_path(path, allowed_dirs, must_exist = TRUE)
        validate_file_size(resolved, max_bytes)

        if (identical(format, "auto")) {
          format <- detect_format(resolved)
        }

        read_by_format(resolved, format, max_rows)
      }

      if (.trace_active()) {
        .with_span("tool.read_file", {
          result <- .do_read()
          .span_event("tool.result", list(tool = "read_file"))
          result
        })
      } else {
        .do_read()
      }
    },
    args = list(path = "character", format = "character")
  )
}

#' Detect file format from extension
#'
#' @param path Character(1). Path to the file.
#' @return Character(1). Detected format string.
#' @noRd
detect_format <- function(path) {
  ext <- tolower(tools::file_ext(path))
  switch(ext,
    csv = "csv",
    json = "json",
    txt = , text = "txt",
    xlsx = , xls = "xlsx",
    parquet = "parquet",
    rds = "rds",
    cli_abort("Cannot auto-detect format for extension: {.val {ext}}")
  )
}

#' Read a file by format
#'
#' @param path Character(1). Resolved file path.
#' @param format Character(1). Format string (csv, json, txt, xlsx, parquet, rds).
#' @param max_rows Integer(1). Maximum rows for tabular formats.
#' @return The file contents (data frame, character vector, or R object).
#' @noRd
read_by_format <- function(path, format, max_rows) {
  switch(format,
    csv = {
      if (rlang::is_installed("readr")) {
        readr::read_csv(path, n_max = max_rows, show_col_types = FALSE)
      } else {
        utils::read.csv(path, nrows = max_rows)
      }
    },
    json = {
      rlang::check_installed("jsonlite", reason = "to read JSON files")
      jsonlite::fromJSON(path)
    },
    txt = {
      readLines(path)
    },
    xlsx = {
      rlang::check_installed("readxl", reason = "to read Excel files")
      readxl::read_excel(path, n_max = max_rows)
    },
    parquet = {
      rlang::check_installed("arrow", reason = "to read Parquet files")
      arrow::read_parquet(path)
    },
    rds = {
      rlang::check_installed("callr", reason = "to safely read RDS files")
      callr::r(function(p) readRDS(p), args = list(path))
    },
    cli_abort("Unsupported format: {.val {format}}")
  )
}
