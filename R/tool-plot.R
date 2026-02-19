# --- Plot rendering tool ---

#' Create a plot rendering tool
#'
#' Returns a [securer::securer_tool()] that evaluates R plotting code
#' and saves the result to a file.
#'
#' @param allowed_dirs Character vector of directories the tool can write to.
#' @param default_width Default plot width in inches. Default 8.
#' @param default_height Default plot height in inches. Default 6.
#' @param max_file_size Maximum output file size. Default `"5MB"`.
#' @param max_calls Maximum invocations. `NULL` means unlimited.
#' @return A `securer_tool` object.
#' @export
plot_tool <- function(allowed_dirs, default_width = 8, default_height = 6,
                      max_file_size = "5MB", max_calls = NULL) {
  max_bytes <- parse_size(max_file_size)
  limiter <- new_rate_limiter(max_calls)

  securer::securer_tool(
    name = "plot",
    description = "Render a plot from R code to a file. Supports png, pdf, svg, jpg formats.",
    fn = function(path, plot_code, width = 0, height = 0, format = "auto") {
      check_rate_limit(limiter)

      resolved <- validate_path(path, allowed_dirs, must_exist = FALSE)

      # Use defaults if width/height are 0 or not provided
      if (is.null(width) || identical(width, 0) || identical(width, 0L)) {
        width <- default_width
      }
      if (is.null(height) || identical(height, 0) || identical(height, 0L)) {
        height <- default_height
      }

      # Detect format from extension
      if (identical(format, "auto")) {
        ext <- tolower(tools::file_ext(path))
        format <- switch(ext,
          png = "png",
          pdf = "pdf",
          svg = "svg",
          jpg = , jpeg = "jpg",
          cli_abort("Cannot auto-detect plot format for extension: {.val {ext}}")
        )
      }

      # Render to temp file
      tmp <- tempfile(fileext = paste0(".", format), tmpdir = dirname(resolved))
      on.exit(unlink(tmp), add = TRUE)

      # Open device
      switch(format,
        png = grDevices::png(tmp, width = width, height = height,
                             units = "in", res = 150),
        pdf = grDevices::pdf(tmp, width = width, height = height),
        svg = grDevices::svg(tmp, width = width, height = height),
        jpg = grDevices::jpeg(tmp, width = width, height = height,
                              units = "in", res = 150),
        cli_abort("Unsupported plot format: {.val {format}}")
      )

      tryCatch({
        eval(parse(text = plot_code), envir = new.env(parent = baseenv()))
        grDevices::dev.off()
      }, error = function(e) {
        tryCatch(grDevices::dev.off(), error = function(e2) NULL)
        cli_abort("Plot code failed: {e$message}")
      })

      # Check size
      validate_file_size(tmp, max_bytes)

      # Move to target
      file.copy(tmp, resolved, overwrite = TRUE)

      list(
        path = resolved,
        size = file.info(resolved)$size,
        format = format
      )
    },
    args = list(
      path = "character",
      plot_code = "character",
      width = "numeric",
      height = "numeric",
      format = "character"
    )
  )
}
