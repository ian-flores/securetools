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
  limiter$call_count <- 0L

  limiter$check <- function() {
    if (is.null(limiter$window_secs)) {
      limiter$call_count <- limiter$call_count + 1L
      if (limiter$call_count > limiter$max_calls) {
        cli_abort("Rate limit exceeded: maximum {limiter$max_calls} lifetime calls.")
      }
      return(invisible(TRUE))
    }

    now <- proc.time()[["elapsed"]]

    cutoff <- now - limiter$window_secs
    limiter$timestamps <- limiter$timestamps[limiter$timestamps > cutoff]

    if (length(limiter$timestamps) >= limiter$max_calls) {
      cli_abort("Rate limit exceeded: {limiter$max_calls} calls per {limiter$window_secs}s window")
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
