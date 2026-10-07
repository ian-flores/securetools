#' Create a data profiling tool
#'
#' Returns a [securer::securer_tool()] that summarizes a data frame.
#'
#' @param max_rows The most rows to profile. Larger data frames are
#'   sampled. Default 100000.
#' @param max_calls The most times the tool can be called. `NULL` (the
#'   default) means no limit.
#'
#' @details
#' For every column the tool reports the type, the number of missing
#' values, and the number of distinct values. Numeric columns also get the
#' minimum, maximum, mean, median, and standard deviation. Character and
#' factor columns get their five most common values with counts.
#'
#' If the data frame has more than `max_rows` rows, the tool profiles a
#' random sample of `max_rows` rows and sets `sampled = TRUE` in the
#' result.
#'
#' The `data` argument is declared as `"list"` in the tool schema, because
#' data frames sent between processes as JSON arrive as lists. The tool
#' turns the list back into a data frame. Inside a `SecureSession`, this
#' currently fails for data frames the size of `iris`; small ones work.
#'
#' @return A `securer_tool` object.
#'
#' @family tool factories
#' @seealso \code{\link[securer]{securer_tool}}
#'
#' @examples
#' \donttest{
#' tool <- tool_data_profile(max_rows = 50000, max_calls = 10)
#' }
#' @export
tool_data_profile <- function(max_rows = 100000, max_calls = NULL) {
  # Factory argument validation
  if (!is.numeric(max_rows) || length(max_rows) != 1L || max_rows < 1L) {
    cli_abort("{.arg max_rows} must be a positive number.")
  }
  if (!is.null(max_calls) && (!is.numeric(max_calls) || length(max_calls) != 1L || max_calls < 1L)) {
    cli_abort("{.arg max_calls} must be NULL or a positive number.")
  }

  limiter <- new_rate_limiter(max_calls)

  securer::securer_tool(
    name = "data_profile",
    description = paste(
      "Compute summary statistics for a data frame including dimensions,",
      "types, NAs, and descriptive stats."
    ),
    fn = function(data) {
      .do_profile <- function() {
        check_rate_limit(limiter)

        # When called via SecureSession IPC, data frames arrive as plain lists
        # due to JSON serialization (simplifyVector = FALSE). Each column
        # becomes a list of individual values. Coerce back to data.frame.
        if (is.list(data) && !is.data.frame(data)) {
          data <- tryCatch(
            coerce_list_to_df(data),
            error = function(e) {
              cli_abort("{.arg data} must be a data frame or coercible list.")
            }
          )
        }

        if (!is.data.frame(data)) {
          cli_abort("{.arg data} must be a data frame.")
        }

        nr <- nrow(data)
        nc <- ncol(data)
        sampled <- FALSE

        if (nr > max_rows) {
          data <- data[sample.int(nr, max_rows), , drop = FALSE]
          sampled <- TRUE
        }

        columns <- lapply(names(data), function(col_name) {
          col <- data[[col_name]]
          info <- list(
            name = col_name,
            type = paste(class(col), collapse = "/"),
            n_missing = sum(is.na(col)),
            n_unique = length(unique(col))
          )

          if (is.numeric(col) || is.integer(col)) {
            vals <- col[!is.na(col)]
            if (length(vals) > 0) {
              info$min <- min(vals)
              info$max <- max(vals)
              info$mean <- mean(vals)
              info$median <- stats::median(vals)
              info$sd <- stats::sd(vals)
            }
          } else if (is.character(col) || is.factor(col)) {
            vals <- col[!is.na(col)]
            if (length(vals) > 0) {
              tbl <- sort(table(vals), decreasing = TRUE)
              top <- utils::head(tbl, 5)
              # Convert table to named list for JSON serialization
              info$top_values <- as.list(stats::setNames(as.integer(top), names(top)))
            }
          }

          info
        })

        list(
          nrow = nr,
          ncol = nc,
          sampled = sampled,
          sample_size = if (sampled) max_rows else nr,
          columns = columns
        )
      }

      if (.trace_active()) {
        .with_span("tool.data_profile", {
          result <- .do_profile()
          .span_event("tool.result", list(tool = "data_profile"))
          result
        })
      } else {
        .do_profile()
      }
    },
    args = list(data = "list")
  )
}

