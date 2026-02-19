# --- URL fetch tool ---

#' Create a URL fetch tool
#'
#' Returns a [securer::securer_tool()] that fetches content from URLs
#' via HTTP GET/HEAD with domain allow-lists and rate limiting.
#'
#' @param allowed_domains Character vector of allowed domains. Use `*.example.com`
#'   for wildcard subdomains. `NULL` (default) allows all domains.
#' @param max_response_size Maximum response body size. Default `"1MB"`.
#' @param timeout_secs Request timeout in seconds. Default 30.
#' @param max_calls Maximum lifetime invocations. `NULL` means unlimited.
#' @param max_calls_per_minute Maximum invocations per 60-second window. Default 10.
#' @return A `securer_tool` object.
#' @export
fetch_url_tool <- function(allowed_domains = NULL, max_response_size = "1MB",
                           timeout_secs = 30, max_calls = NULL,
                           max_calls_per_minute = 10) {
  rlang::check_installed("httr2", reason = "to use fetch_url_tool()")
  max_bytes <- parse_size(max_response_size)
  lifetime_limiter <- new_rate_limiter(max_calls)
  minute_limiter <- new_rate_limiter(max_calls_per_minute, window_secs = 60)

  securer::securer_tool(
    name = "fetch_url",
    description = paste(
      "Fetch content from a URL via HTTP GET or HEAD.",
      "Domain restrictions and rate limits apply."
    ),
    fn = function(url, method = "GET") {
      check_rate_limit(lifetime_limiter)
      check_rate_limit(minute_limiter)

      # Validate method
      method <- toupper(method)
      if (!method %in% c("GET", "HEAD")) {
        cli_abort("Only GET and HEAD methods are allowed, got: {.val {method}}")
      }

      # Parse and validate domain
      parsed <- tryCatch(
        httr2::url_parse(url),
        error = function(e) {
          cli_abort("Could not parse domain from URL: {.url {url}}")
        }
      )
      domain <- parsed$hostname
      if (is.null(domain) || !nzchar(domain)) {
        cli_abort("Could not parse domain from URL: {.url {url}}")
      }

      if (!is.null(allowed_domains)) {
        if (!domain_matches(domain, allowed_domains)) {
          cli_abort("Domain not allowed: {.val {domain}}")
        }
      }

      # Build and execute request
      req <- httr2::request(url)
      req <- httr2::req_timeout(req, seconds = timeout_secs)
      req <- httr2::req_method(req, method)

      resp <- httr2::req_perform(req)

      # Check response size
      body <- httr2::resp_body_string(resp)
      if (nchar(body, type = "bytes") > max_bytes) {
        cli_abort(
          "Response size ({nchar(body, type = 'bytes')} bytes) exceeds limit ({max_bytes} bytes)"
        )
      }

      list(
        status = httr2::resp_status(resp),
        headers = as.list(httr2::resp_headers(resp)),
        body = body
      )
    },
    args = list(url = "character", method = "character")
  )
}

#' Check if a domain matches an allow-list entry
#'
#' @param domain Character(1). The domain to check.
#' @param allowed_domains Character vector of allowed domain patterns.
#' @return Logical(1).
#' @noRd
domain_matches <- function(domain, allowed_domains) {
  for (pattern in allowed_domains) {
    if (startsWith(pattern, "*.")) {
      # Wildcard: *.example.com matches sub.example.com, deep.sub.example.com
      # but NOT example.com itself
      suffix <- substring(pattern, 2) # .example.com
      if (endsWith(domain, suffix) && !identical(domain, substring(pattern, 3))) {
        return(TRUE)
      }
    } else {
      # Exact match
      if (identical(domain, pattern)) {
        return(TRUE)
      }
    }
  }
  FALSE
}
