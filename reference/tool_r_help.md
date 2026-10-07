# Create an R help documentation tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that returns R help pages as text, from the packages you allow.

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

  Character vector of packages whose help pages the tool can return. The
  default is the packages that come with R: base, stats, utils, methods,
  grDevices, graphics, and datasets.

- max_lines:

  The most lines of help text to return. Default 100.

- max_calls:

  The most times the tool can be called. `NULL` means no limit.

## Value

A `securer_tool` object.

## Details

The caller gives a topic and a package, and the package must be in
`allowed_packages`. The help page is converted to plain text with
[`tools::Rd2txt()`](https://rdrr.io/r/tools/Rd2HTML.html) and cut off
after `max_lines` lines.

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
