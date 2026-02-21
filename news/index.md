# Changelog

## securetools 0.1.0

### New Features

- 8 security-hardened tool factories for use with securer:
  - [`read_file_tool()`](https://ian-flores.github.io/securetools/reference/read_file_tool.md)
    – Sandboxed file reading with path validation
  - [`write_file_tool()`](https://ian-flores.github.io/securetools/reference/write_file_tool.md)
    – Sandboxed file writing with size limits
  - [`calculator_tool()`](https://ian-flores.github.io/securetools/reference/calculator_tool.md)
    – Safe expression evaluation with AST validation
  - [`query_sql_tool()`](https://ian-flores.github.io/securetools/reference/query_sql_tool.md)
    – Structured SQL queries with parameterized filters
  - [`fetch_url_tool()`](https://ian-flores.github.io/securetools/reference/fetch_url_tool.md)
    – HTTP fetching with domain allowlists and SSRF protection
  - [`plot_tool()`](https://ian-flores.github.io/securetools/reference/plot_tool.md)
    – Plot generation with restricted code evaluation
  - [`data_profile_tool()`](https://ian-flores.github.io/securetools/reference/data_profile_tool.md)
    – Dataset profiling and summary statistics
  - [`r_help_tool()`](https://ian-flores.github.io/securetools/reference/r_help_tool.md)
    – R documentation lookup with package restrictions
- Internal validation utilities for path safety, SQL identifiers, and
  rate limiting
- Comprehensive test suite covering security rejection paths
- Vignette with usage examples and security model documentation
