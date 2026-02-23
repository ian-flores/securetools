# Create an R help documentation tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that looks up R function documentation from a set of allowed packages.

## Usage

``` r
r_help_tool(
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
[`calculator_tool()`](https://ian-flores.github.io/securetools/reference/calculator_tool.md),
[`data_profile_tool()`](https://ian-flores.github.io/securetools/reference/data_profile_tool.md),
[`fetch_url_tool()`](https://ian-flores.github.io/securetools/reference/fetch_url_tool.md),
[`plot_tool()`](https://ian-flores.github.io/securetools/reference/plot_tool.md),
[`query_sql_tool()`](https://ian-flores.github.io/securetools/reference/query_sql_tool.md),
[`read_file_tool()`](https://ian-flores.github.io/securetools/reference/read_file_tool.md),
[`write_file_tool()`](https://ian-flores.github.io/securetools/reference/write_file_tool.md)

## Examples

``` r
# \donttest{
tool <- r_help_tool(
  allowed_packages = c("base", "stats", "utils"),
  max_lines = 200
)
# }
```
