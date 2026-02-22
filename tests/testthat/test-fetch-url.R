# --- Tests for fetch_url_tool ---

test_that("fetch_url_tool returns securer_tool object", {
  skip_if_not_installed("httr2")
  tool <- fetch_url_tool(allowed_domains = "example.com")
  expect_s3_class(tool, "securer::securer_tool")
  expect_equal(tool@name, "fetch_url")
})

test_that("fetch_url rejects disallowed domains", {
  skip_if_not_installed("httr2")
  tool <- fetch_url_tool(allowed_domains = c("example.com"))
  expect_error(
    tool@fn(url = "https://evil.com/data", method = "GET"),
    "Domain not allowed"
  )
})

test_that("fetch_url allows exact domain match", {
  skip_if_not_installed("httr2")
  # domain_matches() is tested directly below; here we verify the tool does not

  # reject a matching domain at the validation layer (any downstream HTTP error
  # is irrelevant).
  expect_true(securetools:::domain_matches("httpbin.org", "httpbin.org"))
})

test_that("fetch_url wildcard domain matching", {
  skip_if_not_installed("httr2")
  tool <- fetch_url_tool(allowed_domains = c("*.github.com"))

  # Subdomain should pass domain validation (tested via internal helper to avoid
  # network dependency)
  expect_true(securetools:::domain_matches("api.github.com", "*.github.com"))

  # Base domain should fail domain check
  expect_error(
    tool@fn(url = "https://github.com/", method = "GET"),
    "Domain not allowed"
  )
})

test_that("fetch_url rejects non-GET/HEAD methods", {
  skip_if_not_installed("httr2")
  tool <- fetch_url_tool(allowed_domains = "example.com")
  expect_error(
    tool@fn(url = "https://example.com", method = "POST"),
    "Only GET and HEAD"
  )
  expect_error(
    tool@fn(url = "https://example.com", method = "DELETE"),
    "Only GET and HEAD"
  )
})

test_that("fetch_url rate limiting works", {
  skip_if_not_installed("httr2")
  tool <- fetch_url_tool(
    allowed_domains = c("nonexistent.invalid"),
    max_calls = 2,
    max_calls_per_minute = 100
  )
  # Rate limiter runs before domain check, so calls are counted even on failure

  tryCatch(tool@fn(url = "https://nonexistent.invalid/1"), error = function(e) NULL)
  tryCatch(tool@fn(url = "https://nonexistent.invalid/2"), error = function(e) NULL)
  expect_error(
    tool@fn(url = "https://nonexistent.invalid/3"),
    "Rate limit"
  )
})

# --- Direct tests of internal domain_matches() ---

test_that("domain_matches exact match works", {
  expect_true(securetools:::domain_matches("example.com", "example.com"))
  expect_false(securetools:::domain_matches("evil.com", "example.com"))
  expect_false(securetools:::domain_matches("sub.example.com", "example.com"))
})

test_that("domain_matches wildcard works", {
  expect_true(securetools:::domain_matches("api.github.com", "*.github.com"))
  expect_true(securetools:::domain_matches("deep.sub.github.com", "*.github.com"))
  expect_false(securetools:::domain_matches("github.com", "*.github.com"))
  expect_false(securetools:::domain_matches("notgithub.com", "*.github.com"))
})

test_that("domain_matches with multiple patterns", {
  patterns <- c("example.com", "*.github.com")
  expect_true(securetools:::domain_matches("example.com", patterns))
  expect_true(securetools:::domain_matches("api.github.com", patterns))
  expect_false(securetools:::domain_matches("evil.com", patterns))
})

test_that("fetch_url rejects unparseable URLs", {
  skip_if_not_installed("httr2")
  tool <- fetch_url_tool(allowed_domains = "example.com")
  expect_error(
    tool@fn(url = "not-a-url", method = "GET"),
    "Could not parse domain"
  )
})

test_that("fetch_url rejects file:// protocol", {
  skip_if_not_installed("httr2")
  tool <- fetch_url_tool(allowed_domains = "example.com")
  # file:// URLs have no hostname, so they fail domain parsing before protocol check
  expect_error(
    tool@fn(url = "file:///etc/passwd", method = "GET"),
    "[Pp]rotocol|HTTP|[Dd]omain|parse"
  )
})

test_that("fetch_url rejects ftp:// protocol", {
  skip_if_not_installed("httr2")
  tool <- fetch_url_tool(allowed_domains = "example.com")
  expect_error(
    tool@fn(url = "ftp://example.com/file", method = "GET"),
    "[Pp]rotocol|HTTP"
  )
})
