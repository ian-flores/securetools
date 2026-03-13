# Create a file reading tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that reads files from specified directories with format detection and
size limits.

## Usage

``` r
tool_read_file(
  allowed_dirs,
  max_file_size = "50MB",
  max_rows = 10000,
  max_calls = NULL
)

read_file_tool(...)
```

## Arguments

- allowed_dirs:

  Character vector of directories the tool can read from.

- max_file_size:

  Max file size. Default `"50MB"`. Accepts bytes or string like
  `"10MB"`.

- max_rows:

  Maximum rows for tabular formats. Default 10000.

- max_calls:

  Maximum invocations. `NULL` means unlimited.

- ...:

  Arguments passed to `tool_read_file()`.

## Value

A `securer_tool` object.

## Details

Supported formats: csv, json, txt, xlsx, parquet, rds. Format is
detected automatically from the file extension, or can be specified
explicitly via the `format` argument.

Security measures:

- **Path validation**: All paths are resolved via
  [`base::normalizePath()`](https://rdrr.io/r/base/normalizePath.html)
  and checked against `allowed_dirs`. Symlinks are resolved before the
  directory check, preventing symlink-based escapes.

- **RDS sandboxing**: RDS files are deserialized in a separate
  subprocess via callr, isolating the main process from malicious
  objects that execute code on load.

- **Size limits**: Files exceeding `max_file_size` are rejected before
  reading.

- **Row limits**: Tabular formats (csv, xlsx) are capped at `max_rows`
  rows.

## See also

[`securer_tool`](https://ian-flores.github.io/securer/reference/securer_tool.html)

Other tool factories:
[`tool_calculator()`](https://ian-flores.github.io/securetools/reference/tool_calculator.md),
[`tool_data_profile()`](https://ian-flores.github.io/securetools/reference/tool_data_profile.md),
[`tool_fetch_url()`](https://ian-flores.github.io/securetools/reference/tool_fetch_url.md),
[`tool_plot()`](https://ian-flores.github.io/securetools/reference/tool_plot.md),
[`tool_query_sql()`](https://ian-flores.github.io/securetools/reference/tool_query_sql.md),
[`tool_r_help()`](https://ian-flores.github.io/securetools/reference/tool_r_help.md),
[`tool_write_file()`](https://ian-flores.github.io/securetools/reference/tool_write_file.md)

## Examples

``` r
# \donttest{
tool <- tool_read_file(
  allowed_dirs = c("/data/reports", "/data/exports"),
  max_file_size = "10MB",
  max_rows = 5000
)
# }
```
