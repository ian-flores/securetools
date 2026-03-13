# Create a data profiling tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that computes summary statistics for a data frame.

## Usage

``` r
tool_data_profile(max_rows = 1e+05, max_calls = NULL)

data_profile_tool(...)
```

## Arguments

- max_rows:

  Maximum rows to profile. Larger data frames are sampled. Default
  100000.

- max_calls:

  Maximum invocations allowed. `NULL` (default) means unlimited.

- ...:

  Arguments passed to `tool_data_profile()`.

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
[`tool_calculator()`](https://ian-flores.github.io/securetools/reference/tool_calculator.md),
[`tool_fetch_url()`](https://ian-flores.github.io/securetools/reference/tool_fetch_url.md),
[`tool_plot()`](https://ian-flores.github.io/securetools/reference/tool_plot.md),
[`tool_query_sql()`](https://ian-flores.github.io/securetools/reference/tool_query_sql.md),
[`tool_r_help()`](https://ian-flores.github.io/securetools/reference/tool_r_help.md),
[`tool_read_file()`](https://ian-flores.github.io/securetools/reference/tool_read_file.md),
[`tool_write_file()`](https://ian-flores.github.io/securetools/reference/tool_write_file.md)

## Examples

``` r
# \donttest{
tool <- tool_data_profile(max_rows = 50000, max_calls = 10)
# }
```
