#' Create a data profiling tool
#'
#' Returns a [securer::securer_tool()] that computes summary statistics
#' for a data frame.
#'
#' @param max_rows Maximum rows to profile. Larger data frames are sampled.
#'   Default 100000.
#' @param max_calls Maximum invocations allowed. `NULL` (default) means unlimited.
#' @return A `securer_tool` object.
#' @export
data_profile_tool <- function(max_rows = 100000, max_calls = NULL) {
  limiter <- new_rate_limiter(max_calls)

  securer::securer_tool(
    name = "data_profile",
    description = paste(
      "Compute summary statistics for a data frame including dimensions,",
      "types, NAs, and descriptive stats."
    ),
    fn = function(data) {
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
    },
    args = list(data = "list")
  )
}
