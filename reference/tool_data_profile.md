# Create a data profiling tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that summarizes a data frame.

## Usage

``` r
tool_data_profile(max_rows = 1e+05, max_calls = NULL)
```

## Arguments

- max_rows:

  The most rows to profile. Larger data frames are sampled. Default
  100000.

- max_calls:

  The most times the tool can be called. `NULL` (the default) means no
  limit.

## Value

A `securer_tool` object.

## Details

For every column the tool reports the type, the number of missing
values, and the number of distinct values. Numeric columns also get the
minimum, maximum, mean, median, and standard deviation. Character and
factor columns get their five most common values with counts.

If the data frame has more than `max_rows` rows, the tool profiles a
random sample of `max_rows` rows and sets `sampled = TRUE` in the
result.

The `data` argument is declared as `"list"` in the tool schema, because
data frames sent between processes as JSON arrive as lists. The tool
turns the list back into a data frame. Inside a `SecureSession`, this
currently fails for data frames the size of `iris`; small ones work.

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
