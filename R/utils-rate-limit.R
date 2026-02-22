# --- Rate limiting utility (internal) ---

#' @importFrom R6 R6Class
SecuretoolsRateLimiter <- R6::R6Class("SecuretoolsRateLimiter",
  public = list(
    initialize = function(max_calls, window_secs = NULL) {
      private$max_calls <- max_calls
      private$window_secs <- window_secs
      private$timestamps <- numeric(0)
      private$call_count <- 0L
    },
    check = function() {
      if (is.null(private$window_secs)) {
        private$call_count <- private$call_count + 1L
        if (private$call_count > private$max_calls) {
          cli_abort("Rate limit exceeded: maximum {private$max_calls} lifetime calls.")
        }
        return(invisible(TRUE))
      }

      now <- proc.time()[["elapsed"]]
      cutoff <- now - private$window_secs
      private$timestamps <- private$timestamps[private$timestamps > cutoff]

      if (length(private$timestamps) >= private$max_calls) {
        cli_abort("Rate limit exceeded: {private$max_calls} calls per {private$window_secs}s window")
      }

      private$timestamps <- c(private$timestamps, now)
      invisible(TRUE)
    }
  ),
  private = list(
    max_calls = NULL,
    window_secs = NULL,
    timestamps = NULL,
    call_count = NULL
  )
)

#' Create a new rate limiter
#'
#' @param max_calls Maximum number of calls allowed. `NULL` disables limiting.
#' @param window_secs Sliding window in seconds. `NULL` means lifetime limit.
#' @return A `SecuretoolsRateLimiter` R6 object, or `NULL` if `max_calls` is `NULL`.
#' @noRd
new_rate_limiter <- function(max_calls = NULL, window_secs = NULL) {
  if (is.null(max_calls)) {
    return(NULL)
  }
  SecuretoolsRateLimiter$new(max_calls = max_calls, window_secs = window_secs)
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
