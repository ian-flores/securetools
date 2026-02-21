# Create a SQL query tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that queries database tables via a structured interface with
parameterized queries. No raw SQL is accepted – this makes SQL injection
structurally impossible.

## Usage

``` r
query_sql_tool(conn, allowed_tables, max_rows = 1000, max_calls = NULL)
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
[`calculator_tool()`](https://ian-flores.github.io/securetools/reference/calculator_tool.md),
[`data_profile_tool()`](https://ian-flores.github.io/securetools/reference/data_profile_tool.md),
[`fetch_url_tool()`](https://ian-flores.github.io/securetools/reference/fetch_url_tool.md),
[`plot_tool()`](https://ian-flores.github.io/securetools/reference/plot_tool.md),
[`r_help_tool()`](https://ian-flores.github.io/securetools/reference/r_help_tool.md),
[`read_file_tool()`](https://ian-flores.github.io/securetools/reference/read_file_tool.md),
[`write_file_tool()`](https://ian-flores.github.io/securetools/reference/write_file_tool.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tool <- query_sql_tool(
  conn = DBI::dbConnect(RSQLite::SQLite(), ":memory:"),
  allowed_tables = c("customers", "orders"),
  max_rows = 500
)
} # }
```
