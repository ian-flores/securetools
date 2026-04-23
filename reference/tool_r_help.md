# Create an R help documentation tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that looks up R function documentation from a set of allowed packages.

## Usage

``` r
tool_r_help(
  allowed_packages = c("base", "stats", "utils", "methods", "grDevices", "graphics",
    "datasets"),
  max_lines = 100,
  max_calls = NULL
)
```

## Arguments

- allowed_packages:

  Character vector of packages the tool can look up documentation from.
  Default includes base R packages.

- max_lines:

  Maximum lines of help text to return. Default 100.

- max_calls:

  Maximum invocations. `NULL` means unlimited.

## Value

A `securer_tool` object.

## Details

The tool restricts documentation lookup to the packages specified in
`allowed_packages`. Both topic name and package name must be provided;
the package must be in the allow-list.

Help text is rendered as plain text via
[`tools::Rd2txt()`](https://rdrr.io/r/tools/Rd2HTML.html) and truncated
to `max_lines` lines.

## See also

[`securer_tool`](https://ian-flores.github.io/securer/reference/securer_tool.html)

Other tool factories:
[`tool_calculator()`](https://ian-flores.github.io/securetools/reference/tool_calculator.md),
[`tool_data_profile()`](https://ian-flores.github.io/securetools/reference/tool_data_profile.md),
[`tool_fetch_url()`](https://ian-flores.github.io/securetools/reference/tool_fetch_url.md),
[`tool_plot()`](https://ian-flores.github.io/securetools/reference/tool_plot.md),
[`tool_query_sql()`](https://ian-flores.github.io/securetools/reference/tool_query_sql.md),
[`tool_read_file()`](https://ian-flores.github.io/securetools/reference/tool_read_file.md),
[`tool_write_file()`](https://ian-flores.github.io/securetools/reference/tool_write_file.md)

## Examples

``` r
# \donttest{
tool <- tool_r_help(
  allowed_packages = c("base", "stats", "utils"),
  max_lines = 200
)
# }
```
