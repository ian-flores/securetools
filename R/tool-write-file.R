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
#' @return A `securer_tool` object.
#' @export
write_file_tool <- function(allowed_dirs, max_file_size = "10MB",
                            max_calls = NULL, overwrite = FALSE) {
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

      invisible(list(path = resolved, size = file.info(resolved)$size, format = format))
    },
    args = list(path = "character", content = "list", format = "character")
  )
}
