# securetools (development version)

## Bug fixes

* `tool_plot()` could be made to run arbitrary code through indirection,
  for example `do.call("system", ...)`, `lapply(x, system)`, `(system)()`,
  or `x$f()`. Plot code now runs in an environment that holds only the
  allowed functions (its parent is the empty environment), every call must
  name an allowed function directly, `::`/`:::` are rejected, the
  higher-order helpers (`do.call()`, `lapply()`, `Map()`, ...) are off the
  list, and the `ties` argument of `approx()`/`spline()` and friends only
  accepts `"ordered"`.
* `tool_plot()` now finds functions from graphics, grDevices, and stats,
  so `hist()`, `lines()`, `barplot()`, and formula plots work.
* `tool_fetch_url()` works with HTTPS. The resolved IP is now pinned with
  curl's `resolve` option instead of rewriting the URL, so TLS certificate
  and SNI checks use the real host name. Connections are no longer reused,
  so a pooled connection can't bypass the pin.
* `tool_fetch_url()` works on Windows. Host names are now resolved with
  `curl::nslookup()` instead of `utils::nsl()`, which doesn't exist on
  Windows, so every fetch there used to fail with "DNS resolution failed".
  curl is now in Suggests.
* `vignette("agent-integration")` uses ellmer and `securer::as_ellmer_tool()`
  directly instead of the archived orchestr package, which is no longer in
  Suggests.

## Ecosystem consolidation

* Absorbed content from the retired `secure-r-dev-ecosystem` and
  `secureverse` repositories as the ecosystem slims to four packages
  (securer, secureguard, securetools, securebench):
  - New vignette `vignette("data-analyst-agent")` — the flagship
    "Building a Data Analyst Agent" walkthrough, pruned to the
    securer + secureguard + securetools chain. Tracing sections were
    dropped in favour of ellmer's native OpenTelemetry support.
  - New cross-package integration tests
    (`tests/testthat/test-integration-ecosystem.R`); they skip when
    securer/secureguard are not installed and never run on CRAN.
  - New runnable Plumber API example under `inst/examples/plumber/`
    demonstrating guarded chat and sandboxed tool execution.
  - CRAN release checklist and `build-cran-tarball.R` helper ported
    from secureverse into `.github/`.
* README updated for the 4-package lineup; references to the archived
  securetrace/securecontext packages and the umbrella repo removed.
* Tracing ported from the archived `securetrace` package to
  OpenTelemetry via the CRAN `otel` package (soft dependency in
  Suggests). Tool spans keep their `tool.*` names and are emitted under
  the `com.github.ian-flores.securetools` tracer; tools behave
  identically when `otel` is not installed or tracing is disabled.

# securetools 0.2.0

## Breaking changes

* Removed deprecated `*_tool()` aliases: `calculator_tool()`,
  `query_sql_tool()`, `read_file_tool()`, `write_file_tool()`,
  `fetch_url_tool()`, `plot_tool()`, `data_profile_tool()`, and
  `r_help_tool()`. Use the `tool_*()` factories introduced in 0.1.0
  instead. The old names have been warning since 0.1.0.

## New features

* `guarded_tool(tool, input_guards, output_guards)` — compose a
  `securer_tool` with \pkg{secureguard} input/output guardrails.
  Returns a drop-in `securer_tool` replacement that enforces the
  guardrails on every invocation and surfaces failures as tool-call
  errors.
* `with_guards()` — pipe-friendly alias for `guarded_tool()`.

## Dependencies

* `lifecycle` dropped from Imports (deprecation duology removed).
* `secureguard (>= 0.3.0)` added to Suggests for the new adapter.
* Minimum `securer` bumped to 0.2.0.

# securetools 0.1.0

## New Features

* 8 security-hardened tool factories for use with securer:
  - `read_file_tool()` -- Sandboxed file reading with path validation
  - `write_file_tool()` -- Sandboxed file writing with size limits
  - `calculator_tool()` -- Safe expression evaluation with AST validation
  - `query_sql_tool()` -- Structured SQL queries with parameterized filters
  - `fetch_url_tool()` -- HTTP fetching with domain allowlists and SSRF protection
  - `plot_tool()` -- Plot generation with restricted code evaluation
  - `data_profile_tool()` -- Dataset profiling and summary statistics
  - `r_help_tool()` -- R documentation lookup with package restrictions

* Internal validation utilities for path safety, SQL identifiers, and rate limiting
* Comprehensive test suite covering security rejection paths
* Vignette with usage examples and security model documentation
