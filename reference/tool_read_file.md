# Create a file reading tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that reads files from the folders you allow, up to a size limit.

## Usage

``` r
tool_read_file(
  allowed_dirs,
  max_file_size = "50MB",
  max_rows = 10000,
  max_calls = NULL
)
```

## Arguments

- allowed_dirs:

  Character vector of folders the tool can read from.

- max_file_size:

  The largest file the tool will read. Either a number of bytes or a
  string like `"10MB"`. Default `"50MB"`.

- max_rows:

  The most rows to read from csv and xlsx files. Default 10000.

- max_calls:

  The most times the tool can be called. `NULL` means no limit.

## Value

A `securer_tool` object.

## Details

The tool reads csv, json, txt, xlsx, parquet, and rds files. It picks
the format from the file extension unless the caller passes `format`.

Every path is resolved with
[`base::normalizePath()`](https://rdrr.io/r/base/normalizePath.html),
which follows symlinks, and must then be inside one of `allowed_dirs`. A
symlink that points outside those folders is rejected.

Files larger than `max_file_size` are rejected before they are read. csv
and xlsx files are cut off at `max_rows` rows.

Reading an rds file can run code stored in the object, so rds files are
read in a separate R process with callr.

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
