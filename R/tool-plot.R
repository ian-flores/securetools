# --- Plot rendering tool ---

# Allowed function names for plot code
.plot_allowed_fns <- c(
  # Graphics
  "plot", "lines", "points", "abline", "hist", "barplot", "boxplot", "curve",
  "title", "legend", "axis", "mtext", "text", "par", "grid", "segments",
  "arrows", "polygon", "rect", "symbols", "pie", "pairs", "heatmap", "image",
  "contour", "persp", "stripchart", "dotchart", "stars", "sunflowerplot",
  "coplot", "cdplot", "fourfoldplot", "mosaicplot", "assocplot",
  "smoothScatter", "spineplot", "stem",
  # Helpers
  "c", "seq", "seq_len", "seq.int", "length", "rep", "rep_len",
  "paste", "paste0", "sprintf", "format", "nchar", "substr",
  "round", "floor", "ceiling", "trunc", "signif",
  "abs", "sqrt", "log", "log2", "log10", "exp",
  "sin", "cos", "tan", "asin", "acos", "atan",
  "min", "max", "range", "sum", "mean", "median", "diff",
  "cumsum", "cumprod", "cummax", "cummin",
  "rev", "sort", "order", "rank",
  "which", "which.min", "which.max",
  "unique", "duplicated", "table", "cut", "findInterval",
  "approx", "approxfun", "spline", "splinefun",
  "dnorm", "pnorm", "qnorm", "rnorm", "runif", "sample", "set.seed",
  # Data manipulation
  "data.frame", "list", "matrix", "array", "vector",
  "numeric", "integer", "character", "logical",
  "as.numeric", "as.integer", "as.character", "as.logical",
  "names", "nrow", "ncol", "dim", "NROW", "NCOL",
  "head", "tail", "subset", "with", "within", "transform",
  "do.call", "lapply", "sapply", "vapply", "mapply", "Reduce", "Filter", "Map",
  # Operators
  "+", "-", "*", "/", "^", "%%", "%/%",
  "==", "!=", "<", ">", "<=", ">=",
  "&", "|", "!", ":", "~",
  # Constants/special
  "TRUE", "FALSE", "T", "F", "NA", "NULL", "Inf", "NaN",
  "pi", "LETTERS", "letters", "month.abb", "month.name",
  # Flow
  "if", "for", "while", "{", "(", "<-", "=", "[", "[[", "$"
)

#' Validate a plot AST node recursively
#'
#' Walks the parse tree and rejects anything outside the allowed
#' plotting/math/data function set.
#'
#' @param expr A language object from `parse()`.
#' @return `invisible(TRUE)` on success; errors otherwise.
#' @noRd
.validate_plot_ast <- function(expr) {
  # Literals: numeric, character, logical, NULL
  if (is.numeric(expr) || is.character(expr) || is.logical(expr) || is.null(expr)) {
    return(invisible(TRUE))
  }

  # Symbols (variable references) are allowed
  if (is.symbol(expr)) {
    return(invisible(TRUE))
  }

  if (is.call(expr)) {
    fn <- expr[[1]]
    # Get the function name as a string
    fn_name <- if (is.symbol(fn)) {
      as.character(fn)
    } else if (is.character(fn)) {
      fn
    } else {
      # For complex call expressions (e.g. pkg::fn), recurse into them
      .validate_plot_ast(fn)
      NULL
    }

    if (!is.null(fn_name) && !fn_name %in% .plot_allowed_fns) {
      cli_abort("Function not allowed in plot code: {.fn {fn_name}}")
    }

    # Recursively validate all arguments
    for (i in seq_along(expr)[-1]) {
      .validate_plot_ast(expr[[i]])
    }
    return(invisible(TRUE))
  }

  # Pairlists (formals), etc. -- recurse into elements
  if (is.pairlist(expr)) {
    for (i in seq_along(expr)) {
      if (!rlang::is_missing(expr[[i]])) {
        .validate_plot_ast(expr[[i]])
      }
    }
    return(invisible(TRUE))
  }

  invisible(TRUE)
}

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
#' @param default_dpi Default resolution in dots per inch for raster formats
#'   (png, jpg). Default 150.
#' @return A `securer_tool` object.
#'
#' @details
#' The plot tool evaluates R plotting code in a restricted environment.
#' Before evaluation, an AST walk validates that only allowed functions are
#' called, preventing arbitrary code execution. The following categories of
#' functions are permitted:
#'
#' \itemize{
#'   \item **Graphics**: `plot`, `lines`, `points`, `abline`, `hist`,
#'     `barplot`, `boxplot`, `curve`, `title`, `legend`, `axis`, `mtext`,
#'     `text`, `par`, `grid`, `segments`, `arrows`, `polygon`, `rect`,
#'     `symbols`, `pie`, `pairs`, `heatmap`, `image`, `contour`, `persp`,
#'     `stripchart`, `dotchart`, `stars`, `sunflowerplot`, `coplot`,
#'     `cdplot`, `fourfoldplot`, `mosaicplot`, `assocplot`,
#'     `smoothScatter`, `spineplot`, `stem`
#'   \item **Helpers**: mathematical functions (`sqrt`, `log`, `exp`, etc.),
#'     string functions (`paste`, `sprintf`, etc.), and statistical
#'     distributions (`dnorm`, `rnorm`, etc.)
#'   \item **Data manipulation**: `data.frame`, `list`, `matrix`, `lapply`,
#'     `sapply`, `subset`, `with`, and others
#'   \item **Operators**: arithmetic, comparison, and logical operators
#'   \item **Flow control**: `if`, `for`, `while`, `{`, assignment
#' }
#'
#' Supported output formats: png, pdf, svg, jpg/jpeg. The format is
#' auto-detected from the file extension by default.
#'
#' @family tool factories
#' @seealso \code{\link[securer]{securer_tool}}
#'
#' @examples
#' \donttest{
#' plt <- tool_plot(allowed_dirs = tempdir())
#' # Basic scatter plot
#' plt@fn(
#'   path = file.path(tempdir(), "scatter.png"),
#'   plot_code = "plot(1:10, (1:10)^2, main = 'Example')"
#' )
#'
#' # With custom dimensions and DPI
#' plt <- tool_plot(
#'   allowed_dirs = tempdir(),
#'   default_width = 10,
#'   default_height = 8,
#'   default_dpi = 300
#' )
#' }
#'
#' @export
tool_plot <- function(allowed_dirs, default_width = 8, default_height = 6,
                      max_file_size = "5MB", max_calls = NULL,
                      default_dpi = 150) {
  if (!is.character(allowed_dirs) || length(allowed_dirs) == 0L) {
    cli_abort("{.arg allowed_dirs} must be a non-empty character vector.")
  }
  if (!is.null(max_calls) && (!is.numeric(max_calls) || length(max_calls) != 1L || max_calls < 1L)) {
    cli_abort("{.arg max_calls} must be NULL or a positive number.")
  }
  if (!is.numeric(default_dpi) || length(default_dpi) != 1L || default_dpi < 1) {
    cli_abort("{.arg default_dpi} must be a positive number.")
  }

  max_bytes <- parse_size(max_file_size)
  limiter <- new_rate_limiter(max_calls)

  securer::securer_tool(
    name = "plot",
    description = "Render a plot from R code to a file. Supports png, pdf, svg, jpg formats.",
    fn = function(path, plot_code, width = NULL, height = NULL, format = "auto") {
      .do_plot <- function() {
        check_rate_limit(limiter)

        resolved <- validate_path(path, allowed_dirs, must_exist = FALSE)

        # Use defaults if width/height are not provided
        if (is.null(width)) {
          width <- default_width
        }
        if (is.null(height)) {
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

        # Parse and validate plot code AST
        parsed <- tryCatch(
          parse(text = plot_code),
          error = function(e) cli_abort("Invalid plot code: {e$message}")
        )
        for (i in seq_along(parsed)) {
          .validate_plot_ast(parsed[[i]])
        }

        # Render to temp file
        tmp <- tempfile(fileext = paste0(".", format), tmpdir = dirname(resolved))
        on.exit(unlink(tmp), add = TRUE)

        # Open device
        switch(format,
          png = grDevices::png(tmp, width = width, height = height,
                               units = "in", res = default_dpi),
          pdf = grDevices::pdf(tmp, width = width, height = height),
          svg = grDevices::svg(tmp, width = width, height = height),
          jpg = grDevices::jpeg(tmp, width = width, height = height,
                                units = "in", res = default_dpi),
          cli_abort("Unsupported plot format: {.val {format}}")
        )

        tryCatch({
          eval(parsed, envir = new.env(parent = baseenv()))
          grDevices::dev.off()
        }, error = function(e) {
          tryCatch(grDevices::dev.off(), error = function(e2) NULL)
          cli_abort("Plot code failed: {e$message}")
        })

        # Check size
        validate_file_size(tmp, max_bytes)

        # Move to target
        file.copy(tmp, resolved, overwrite = TRUE)

        # Re-validate after write to catch symlink TOCTOU attacks
        validate_written_path(resolved, allowed_dirs)

        list(
          path = resolved,
          size = file.info(resolved)$size,
          format = format
        )
      }

      if (.trace_active()) {
        securetrace::with_span("tool.plot", type = "tool", {
          result <- .do_plot()
          .span_event("tool.result", list(tool = "plot"))
          result
        })
      } else {
        .do_plot()
      }
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

#' @rdname tool_plot
#' @param ... Arguments passed to [tool_plot()].
#' @export
plot_tool <- function(...) {
  lifecycle::deprecate_warn("0.3.0", "plot_tool()", "tool_plot()")
  tool_plot(...)
}
