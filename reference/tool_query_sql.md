# Create a SQL query tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that runs a SELECT on one table. The caller names the table, the
columns, and an optional filter, and the tool writes the SQL. It never
accepts SQL text, so there is nothing to inject into.

## Usage

``` r
tool_query_sql(conn, allowed_tables, max_rows = 1000, max_calls = NULL)
```

## Arguments

- conn:

  A DBI connection.

- allowed_tables:

  Character vector of tables the tool can query.

- max_rows:

  The most rows a query returns. Default 1000.

- max_calls:

  The most times the tool can be called. `NULL` means no limit.

## Value

A `securer_tool` object.

## Details

The table must be one of `allowed_tables`. Column names aren't checked
against a list, but they must be plain identifiers (letters, digits, and
underscores, not starting with a digit). Table and column names are also
quoted with
[`DBI::dbQuoteIdentifier()`](https://dbi.r-dbi.org/reference/dbQuoteIdentifier.html).

The filter is a single `column = value` condition. The value is passed
as a query parameter and is never pasted into the SQL. Every query ends
with `LIMIT max_rows`.

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
