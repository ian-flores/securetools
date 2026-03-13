# Create a SQL query tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that queries database tables via a structured interface with
parameterized queries. No raw SQL is accepted – this makes SQL injection
structurally impossible.

## Usage

``` r
tool_query_sql(conn, allowed_tables, max_rows = 1000, max_calls = NULL)

query_sql_tool(...)
```

## Arguments

- conn:

  A DBI connection object.

- allowed_tables:

  Character vector of table names the tool can query.

- max_rows:

  Maximum rows returned. Default 1000.

- max_calls:

  Maximum invocations. `NULL` means unlimited.

- ...:

  Arguments passed to `tool_query_sql()`.

## Value

A `securer_tool` object.

## Details

Security constraints:

- **Structured SELECT only**: The tool constructs SELECT queries from
  structured arguments. No raw SQL is accepted, making SQL injection
  structurally impossible.

- **Parameterized filters**: Filter values are passed as query
  parameters, never interpolated into SQL strings.

- **Identifier quoting**: Table and column names are quoted with
  [`DBI::dbQuoteIdentifier()`](https://dbi.r-dbi.org/reference/dbQuoteIdentifier.html)
  after passing allow-list validation, providing defense in depth.

- **Table allow-list**: Only tables listed in `allowed_tables` can be
  queried.

## See also

[`securer_tool`](https://ian-flores.github.io/securer/reference/securer_tool.html)

Other tool factories:
[`tool_calculator()`](https://ian-flores.github.io/securetools/reference/tool_calculator.md),
[`tool_data_profile()`](https://ian-flores.github.io/securetools/reference/tool_data_profile.md),
[`tool_fetch_url()`](https://ian-flores.github.io/securetools/reference/tool_fetch_url.md),
[`tool_plot()`](https://ian-flores.github.io/securetools/reference/tool_plot.md),
[`tool_r_help()`](https://ian-flores.github.io/securetools/reference/tool_r_help.md),
[`tool_read_file()`](https://ian-flores.github.io/securetools/reference/tool_read_file.md),
[`tool_write_file()`](https://ian-flores.github.io/securetools/reference/tool_write_file.md)

## Examples

``` r
# \donttest{
tool <- tool_query_sql(
  conn = DBI::dbConnect(RSQLite::SQLite(), ":memory:"),
  allowed_tables = c("customers", "orders"),
  max_rows = 500
)
# }
```
