# Create a data profiling tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that computes summary statistics for a data frame.

## Usage

``` r
data_profile_tool(max_rows = 1e+05, max_calls = NULL)
```

## Arguments

- max_rows:

  Maximum rows to profile. Larger data frames are sampled. Default
  100000.

- max_calls:

  Maximum invocations allowed. `NULL` (default) means unlimited.

## Value

A `securer_tool` object.

## Details

Computes per-column statistics including type, missing count, and unique
count. For numeric and integer columns, also computes min, max, mean,
median, and standard deviation. For character and factor columns,
returns the top 5 most frequent values with counts.

When the input data frame exceeds `max_rows`, a random sample of
`max_rows` rows is profiled and the result indicates that sampling
occurred.

The `data` argument is declared as type `"list"` in the tool schema
because the IPC serialization layer converts data frames to lists. The
tool automatically coerces list input back to a data frame.

## See also

[`securer_tool`](https://ian-flores.github.io/securer/reference/securer_tool.html)

Other tool factories:
[`calculator_tool()`](https://ian-flores.github.io/securetools/reference/calculator_tool.md),
[`fetch_url_tool()`](https://ian-flores.github.io/securetools/reference/fetch_url_tool.md),
[`plot_tool()`](https://ian-flores.github.io/securetools/reference/plot_tool.md),
[`query_sql_tool()`](https://ian-flores.github.io/securetools/reference/query_sql_tool.md),
[`r_help_tool()`](https://ian-flores.github.io/securetools/reference/r_help_tool.md),
[`read_file_tool()`](https://ian-flores.github.io/securetools/reference/read_file_tool.md),
[`write_file_tool()`](https://ian-flores.github.io/securetools/reference/write_file_tool.md)

## Examples

``` r
# \donttest{
tool <- data_profile_tool(max_rows = 50000, max_calls = 10)
# }
```
