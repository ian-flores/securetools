# Create a file reading tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that reads files from specified directories with format detection and
size limits.

## Usage

``` r
read_file_tool(
  allowed_dirs,
  max_file_size = "50MB",
  max_rows = 10000,
  max_calls = NULL
)
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
[`calculator_tool()`](https://ian-flores.github.io/securetools/reference/calculator_tool.md),
[`data_profile_tool()`](https://ian-flores.github.io/securetools/reference/data_profile_tool.md),
[`fetch_url_tool()`](https://ian-flores.github.io/securetools/reference/fetch_url_tool.md),
[`plot_tool()`](https://ian-flores.github.io/securetools/reference/plot_tool.md),
[`query_sql_tool()`](https://ian-flores.github.io/securetools/reference/query_sql_tool.md),
[`r_help_tool()`](https://ian-flores.github.io/securetools/reference/r_help_tool.md),
[`write_file_tool()`](https://ian-flores.github.io/securetools/reference/write_file_tool.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tool <- read_file_tool(
  allowed_dirs = c("/data/reports", "/data/exports"),
  max_file_size = "10MB",
  max_rows = 5000
)
} # }
```
