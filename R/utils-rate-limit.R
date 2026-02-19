# --- Rate limiting utility (internal) ---

#' Create a new rate limiter
#'
#' @param max_calls Maximum number of calls allowed. `NULL` disables limiting.
#' @param window_secs Sliding window in seconds. `NULL` means lifetime limit.
#' @return A rate limiter environment with class `"securetools_rate_limiter"`,
#'   or `NULL` if `max_calls` is `NULL`.
#' @noRd
new_rate_limiter <- function(max_calls = NULL, window_secs = NULL) {
  if (is.null(max_calls)) {
    return(NULL)
  }

  limiter <- new.env(parent = emptyenv())
  limiter$max_calls <- max_calls
  limiter$window_secs <- window_secs
  limiter$timestamps <- numeric(0)

  limiter$check <- function() {
    now <- proc.time()[["elapsed"]]

    if (!is.null(limiter$window_secs)) {
      cutoff <- now - limiter$window_secs
      limiter$timestamps <- limiter$timestamps[limiter$timestamps > cutoff]
    }

    if (length(limiter$timestamps) >= limiter$max_calls) {
      per_window_msg <- if (!is.null(limiter$window_secs)) {
        paste0(" per ", limiter$window_secs, "s window")
      } else {
        " per session"
      }
      cli_abort("Rate limit exceeded: {limiter$max_calls} calls{per_window_msg}")
    }

    limiter$timestamps <- c(limiter$timestamps, now)
    invisible(TRUE)
  }

  class(limiter) <- "securetools_rate_limiter"
  limiter
}

#' Check a rate limiter (no-op if NULL)
#'
#' @param limiter A rate limiter or `NULL`.
#' @noRd
check_rate_limit <- function(limiter) {
  if (!is.null(limiter)) {
    limiter$check()
  }
  invisible(NULL)
}
