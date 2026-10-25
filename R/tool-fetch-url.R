# --- URL fetch tool ---

#' Create a URL fetch tool
#'
#' Returns a [securer::securer_tool()] that makes GET and HEAD requests to
#' the domains you allow.
#'
#' @param allowed_domains Character vector of domains the tool may contact.
#'   Required. `*.example.com` matches any subdomain of `example.com` but
#'   not `example.com` itself.
#' @param max_response_size The largest response body the tool will
#'   return. Default `"1MB"`.
#' @param timeout_secs How long to wait for a response, in seconds.
#'   Default 30.
#' @param max_calls The most times the tool can be called in total. `NULL`
#'   means no limit.
#' @param max_calls_per_minute The most calls allowed in any 60 seconds.
#'   Default 10.
#'
#' @details
#' Only `http` and `https` URLs are accepted, and only GET and HEAD.
#' The host must match `allowed_domains`. For example, `*.example.com`
#' matches `api.example.com` and `deep.sub.example.com`, but not
#' `example.com`.
#'
#' The tool looks up the host's IP address once and refuses private and
#' reserved addresses (10.x, 172.16-31.x, 192.168.x, 127.x, 169.254.x, and
#' 0.0.0.0) as well as every IPv6 address. It then tells curl to use that
#' IP for the host (curl's `resolve` option), so a second DNS lookup can't
#' point it somewhere else. The URL keeps the host name, so HTTPS
#' certificates are checked against it as usual. Redirects are not
#' followed.
#'
#' curl stops the download at `max_response_size`, and the body size is
#' checked again afterwards.
#'
#' @return A `securer_tool` object.
#'
#' @family tool factories
#' @seealso \code{\link[securer]{securer_tool}}
#'
#' @examples
#' \donttest{
#' tool <- tool_fetch_url(
#'   allowed_domains = c("api.example.com", "*.cdn.example.com"),
#'   max_response_size = "512KB",
#'   timeout_secs = 10
#' )
#' }
#' @export
tool_fetch_url <- function(allowed_domains, max_response_size = "1MB",
                           timeout_secs = 30, max_calls = NULL,
                           max_calls_per_minute = 10) {
  # Factory argument validation
  if (!is.character(allowed_domains) || length(allowed_domains) == 0L) {
    cli_abort("{.arg allowed_domains} must be a non-empty character vector of allowed domains.")
  }
  if (!is.null(max_calls) && (!is.numeric(max_calls) || length(max_calls) != 1L || max_calls < 1L)) {
    cli_abort("{.arg max_calls} must be NULL or a positive number.")
  }
  if (!is.numeric(timeout_secs) || length(timeout_secs) != 1L || timeout_secs <= 0) {
    cli_abort("{.arg timeout_secs} must be a positive number.")
  }

  rlang::check_installed(c("httr2", "curl"), reason = "to use tool_fetch_url()")
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
      .do_fetch <- function() {
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

        # Protocol validation
        scheme <- tolower(parsed$scheme %||% "")
        if (!scheme %in% c("http", "https")) {
          cli_abort("Only HTTP and HTTPS protocols are allowed, not {.val {scheme}}.")
        }

        # Private IP blocking (SSRF prevention) -- check raw IP literals only
        # (hostnames are checked after DNS resolution below)
        if (.is_ip_literal(domain) && .is_ip_private(domain)) {
          cli_abort("Requests to private/internal IP addresses are not allowed.")
        }

        # Domain allow-list check
        if (!domain_matches(domain, allowed_domains)) {
          cli_abort("Domain not allowed: {.val {domain}}")
        }

        # DNS rebinding prevention: resolve hostname once, validate the resolved
        # IP, then tell curl to use that IP for this host (CURLOPT_RESOLVE) so
        # the server cannot return a different address on a second lookup.
        # The URL keeps the host name, so TLS SNI and certificate checks work.
        resolved_ip <- .resolve_host(domain)
        if (is.null(resolved_ip)) {
          cli_abort("DNS resolution failed for host: {.val {domain}}")
        }
        if (.is_ip_private(resolved_ip)) {
          cli_abort("Requests to private/internal IP addresses are not allowed.")
        }

        # Build and execute request, pinned to the resolved IP
        req <- httr2::request(url)
        req <- httr2::req_options(req, resolve = .pin_resolve(parsed, resolved_ip))
        # A pooled connection to the same host may point at another IP, and
        # curl would reuse it without looking at `resolve`
        req <- httr2::req_options(req, fresh_connect = TRUE, forbid_reuse = TRUE)
        req <- httr2::req_timeout(req, seconds = timeout_secs)
        req <- httr2::req_method(req, method)
        req <- httr2::req_options(req, followlocation = FALSE)
        req <- httr2::req_options(req, maxfilesize = max_bytes)

        resp <- httr2::req_perform(req)

        # Check response size (belt-and-suspenders backup)
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
      }

      if (.trace_active()) {
        .with_span("tool.fetch_url", {
          result <- .do_fetch()
          .span_event("tool.result", list(tool = "fetch_url"))
          result
        })
      } else {
        .do_fetch()
      }
    },
    args = list(url = "character", method = "character")
  )
}

#' Check if a string looks like an IP literal (not a hostname)
#'
#' @param host Character(1). A hostname or IP address string.
#' @return Logical(1). TRUE if the string looks like an IPv4 or IPv6 literal.
#' @noRd
.is_ip_literal <- function(host) {
  # IPv6 literal (contains colon)
  if (grepl(":", host, fixed = TRUE)) return(TRUE)
  # IPv4 literal (all dot-separated parts are integers)
  parts <- strsplit(host, ".", fixed = TRUE)[[1]]
  if (length(parts) != 4L) return(FALSE)
  all(!is.na(suppressWarnings(as.integer(parts))))
}

#' Resolve a host name to one IPv4 address
#'
#' Uses curl's resolver, which works on every platform. (`utils::nsl()`
#' does not exist on Windows.) IPv4 only, so the address can be checked
#' against the private ranges in [.is_ip_private()].
#'
#' @param host Character(1). A host name or IPv4 literal.
#' @return Character(1) IPv4 address, or `NULL` if the host doesn't resolve.
#' @noRd
.resolve_host <- function(host) {
  tryCatch(
    curl::nslookup(host, ipv4_only = TRUE, error = FALSE),
    error = function(e) NULL
  )
}

#' Check if a hostname or IP string is a private/reserved address
#'
#' Resolves hostnames via [.resolve_host()] first, then checks the IP.
#'
#' @param host Character(1). A hostname or IP address string.
#' @return Logical(1).
#' @noRd
.is_private_ip <- function(host) {
  ip <- .resolve_host(host)
  if (is.null(ip)) return(FALSE)
  .is_ip_private(ip)
}

#' Check if an IP address string falls in a private/reserved range
#'
#' Pure check on an already-resolved IP address -- no DNS resolution.
#'
#' @param ip Character(1). An IPv4 or IPv6 address string.
#' @return Logical(1).
#' @noRd
.is_ip_private <- function(ip) {
  # IPv6 (contains colon) -- deny all by default
  if (grepl(":", ip, fixed = TRUE)) return(TRUE)

  # Only check strings that look like IPv4 addresses (all digits and dots).
  # Hostnames contain letters and should not be classified here.

  if (!grepl("^[0-9.]+$", ip)) return(FALSE)

  octets <- as.integer(strsplit(ip, ".", fixed = TRUE)[[1]])
  if (length(octets) != 4) return(TRUE) # Malformed -- deny by default

  # 127.0.0.0/8
  if (octets[1] == 127L) return(TRUE)
  # 10.0.0.0/8
  if (octets[1] == 10L) return(TRUE)
  # 172.16.0.0/12
  if (octets[1] == 172L && octets[2] >= 16L && octets[2] <= 31L) return(TRUE)
  # 192.168.0.0/16
  if (octets[1] == 192L && octets[2] == 168L) return(TRUE)
  # 169.254.0.0/16 (link-local)
  if (octets[1] == 169L && octets[2] == 254L) return(TRUE)
  # 0.0.0.0
  if (all(octets == 0L)) return(TRUE)

  FALSE
}

#' Build a curl resolve entry that pins a host to an IP address
#'
#' @param parsed List returned by `httr2::url_parse()`.
#' @param ip Character(1). The resolved IP to connect to.
#' @return Character(1). A `"host:port:ip"` entry for `CURLOPT_RESOLVE`.
#' @noRd
.pin_resolve <- function(parsed, ip) {
  port <- parsed$port
  if (is.null(port) || is.na(port) || !nzchar(port)) {
    port <- if (identical(tolower(parsed$scheme), "https")) 443L else 80L
  }
  paste0(parsed$hostname, ":", port, ":", ip)
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
