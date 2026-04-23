# Changelog

## securetools 0.2.0

### Breaking changes

- Removed deprecated `*_tool()` aliases: `calculator_tool()`,
  `query_sql_tool()`, `read_file_tool()`, `write_file_tool()`,
  `fetch_url_tool()`, `plot_tool()`, `data_profile_tool()`, and
  `r_help_tool()`. Use the `tool_*()` factories introduced in 0.1.0
  instead. The old names have been warning since 0.1.0.

### New features

- `guarded_tool(tool, input_guards, output_guards)` — compose a
  `securer_tool` with input/output guardrails. Returns a drop-in
  `securer_tool` replacement that enforces the guardrails on every
  invocation and surfaces failures as tool-call errors.
- [`with_guards()`](https://ian-flores.github.io/securetools/reference/with_guards.md)
  — pipe-friendly alias for
  [`guarded_tool()`](https://ian-flores.github.io/securetools/reference/guarded_tool.md).

### Dependencies

- `lifecycle` dropped from Imports (deprecation duology removed).
- `secureguard (>= 0.3.0)` added to Suggests for the new adapter.
- Minimum `securer` bumped to 0.2.0.

## securetools 0.1.0

### New Features

- 8 security-hardened tool factories for use with securer:
  - `read_file_tool()` – Sandboxed file reading with path validation
  - `write_file_tool()` – Sandboxed file writing with size limits
  - `calculator_tool()` – Safe expression evaluation with AST validation
  - `query_sql_tool()` – Structured SQL queries with parameterized
    filters
  - `fetch_url_tool()` – HTTP fetching with domain allowlists and SSRF
    protection
  - `plot_tool()` – Plot generation with restricted code evaluation
  - `data_profile_tool()` – Dataset profiling and summary statistics
  - `r_help_tool()` – R documentation lookup with package restrictions
- Internal validation utilities for path safety, SQL identifiers, and
  rate limiting
- Comprehensive test suite covering security rejection paths
- Vignette with usage examples and security model documentation
