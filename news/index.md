# Changelog

## securetools 0.1.0

### New Features

- 8 security-hardened tool factories for use with securer:
  - [`read_file_tool()`](https://ian-flores.github.io/securetools/reference/tool_read_file.md)
    – Sandboxed file reading with path validation
  - [`write_file_tool()`](https://ian-flores.github.io/securetools/reference/tool_write_file.md)
    – Sandboxed file writing with size limits
  - [`calculator_tool()`](https://ian-flores.github.io/securetools/reference/tool_calculator.md)
    – Safe expression evaluation with AST validation
  - [`query_sql_tool()`](https://ian-flores.github.io/securetools/reference/tool_query_sql.md)
    – Structured SQL queries with parameterized filters
  - [`fetch_url_tool()`](https://ian-flores.github.io/securetools/reference/tool_fetch_url.md)
    – HTTP fetching with domain allowlists and SSRF protection
  - [`plot_tool()`](https://ian-flores.github.io/securetools/reference/tool_plot.md)
    – Plot generation with restricted code evaluation
  - [`data_profile_tool()`](https://ian-flores.github.io/securetools/reference/tool_data_profile.md)
    – Dataset profiling and summary statistics
  - [`r_help_tool()`](https://ian-flores.github.io/securetools/reference/tool_r_help.md)
    – R documentation lookup with package restrictions
- Internal validation utilities for path safety, SQL identifiers, and
  rate limiting
- Comprehensive test suite covering security rejection paths
- Vignette with usage examples and security model documentation
