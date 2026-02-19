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
