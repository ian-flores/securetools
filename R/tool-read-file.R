# --- File reading tool ---

#' Create a file reading tool
#'
#' Returns a [securer::securer_tool()] that reads files from specified
#' directories with format detection and size limits.
#'
#' @param allowed_dirs Character vector of directories the tool can read from.
#' @param max_file_size Max file size. Default `"50MB"`. Accepts bytes or
#'   string like `"10MB"`.
#' @param max_rows Maximum rows for tabular formats. Default 10000.
#' @param max_calls Maximum invocations. `NULL` means unlimited.
#' @return A `securer_tool` object.
#' @export
read_file_tool <- function(allowed_dirs, max_file_size = "50MB", max_rows = 10000,
                           max_calls = NULL) {
  max_bytes <- parse_size(max_file_size)
  limiter <- new_rate_limiter(max_calls)

  securer::securer_tool(
    name = "read_file",
    description = paste(
      "Read a file from allowed directories.",
      "Supports csv, json, txt, xlsx, parquet, rds formats."
    ),
    fn = function(path, format = "auto") {
      check_rate_limit(limiter)

      resolved <- validate_path(path, allowed_dirs, must_exist = TRUE)
      validate_file_size(resolved, max_bytes)

      if (identical(format, "auto")) {
        format <- detect_format(resolved)
      }

      read_by_format(resolved, format, max_rows)
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
      readRDS(path)
    },
    cli_abort("Unsupported format: {.val {format}}")
  )
}
