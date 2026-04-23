# Package index

## File I/O

Tools for reading and writing files with path scoping and size limits.

- [`tool_read_file()`](https://ian-flores.github.io/securetools/reference/tool_read_file.md)
  : Create a file reading tool
- [`tool_write_file()`](https://ian-flores.github.io/securetools/reference/tool_write_file.md)
  : Create a file writing tool

## Database

Structured database queries with parameterized filters.

- [`tool_query_sql()`](https://ian-flores.github.io/securetools/reference/tool_query_sql.md)
  : Create a SQL query tool

## Data Analysis

Tools for data profiling, calculation, and visualization.

- [`tool_data_profile()`](https://ian-flores.github.io/securetools/reference/tool_data_profile.md)
  : Create a data profiling tool
- [`tool_calculator()`](https://ian-flores.github.io/securetools/reference/tool_calculator.md)
  : Create a calculator tool
- [`tool_plot()`](https://ian-flores.github.io/securetools/reference/tool_plot.md)
  : Create a plot rendering tool

## Web

HTTP fetch with domain allow-lists and rate limiting.

- [`tool_fetch_url()`](https://ian-flores.github.io/securetools/reference/tool_fetch_url.md)
  : Create a URL fetch tool

## Documentation

R help documentation lookup.

- [`tool_r_help()`](https://ian-flores.github.io/securetools/reference/tool_r_help.md)
  : Create an R help documentation tool

## Guardrail Composition

Wrap tools with secureguard guardrails on input and output.

- [`guarded_tool()`](https://ian-flores.github.io/securetools/reference/guarded_tool.md)
  : Wrap a securer_tool with input and output guardrails

- [`with_guards()`](https://ian-flores.github.io/securetools/reference/with_guards.md)
  :

  Pipe-friendly alias for
  [`guarded_tool()`](https://ian-flores.github.io/securetools/reference/guarded_tool.md)
