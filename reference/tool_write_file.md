# Create a file writing tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that writes data to files in specified directories with size limits and
overwrite protection.

## Usage

``` r
tool_write_file(
  allowed_dirs,
  max_file_size = "10MB",
  max_calls = NULL,
  overwrite = FALSE
)
```

## Arguments

- allowed_dirs:

  Character vector of directories the tool can write to.

- max_file_size:

  Max output file size. Default `"10MB"`.

- max_calls:

  Maximum invocations. `NULL` means unlimited.

- overwrite:

  Whether to allow overwriting existing files. Default `FALSE`.

## Value

A `securer_tool` object.

## Details

The `content` argument type is declared as `"list"` in the tool schema
because the IPC serialization layer (JSON) converts most R objects to
lists. In practice, callers should pass:

- A `data.frame` for CSV and JSON formats

- A character vector for TXT format

- Any R object for RDS format

Supported formats: csv, json, txt, rds. Format is auto-detected from the
file extension, or can be specified explicitly.

Security constraints:

- **Atomic writes**: Data is written to a temp file first, validated for
  size, then moved to the target path.

- **Overwrite protection**: By default, existing files cannot be
  overwritten (controlled by the `overwrite` parameter).

- **Symlink resolution**: Target paths are resolved via
  [`base::normalizePath()`](https://rdrr.io/r/base/normalizePath.html)
  to prevent symlink-based directory escapes.

- **Size limits**: Written files exceeding `max_file_size` are rejected
  before being moved to the target.

## See also

[`securer_tool`](https://ian-flores.github.io/securer/reference/securer_tool.html),
[`tool_read_file`](https://ian-flores.github.io/securetools/reference/tool_read_file.md)

Other tool factories:
[`tool_calculator()`](https://ian-flores.github.io/securetools/reference/tool_calculator.md),
[`tool_data_profile()`](https://ian-flores.github.io/securetools/reference/tool_data_profile.md),
[`tool_fetch_url()`](https://ian-flores.github.io/securetools/reference/tool_fetch_url.md),
[`tool_plot()`](https://ian-flores.github.io/securetools/reference/tool_plot.md),
[`tool_query_sql()`](https://ian-flores.github.io/securetools/reference/tool_query_sql.md),
[`tool_r_help()`](https://ian-flores.github.io/securetools/reference/tool_r_help.md),
[`tool_read_file()`](https://ian-flores.github.io/securetools/reference/tool_read_file.md)

## Examples

``` r
# \donttest{
tool <- tool_write_file(
  allowed_dirs = "/data/exports",
  max_file_size = "5MB",
  overwrite = FALSE
)
# }
```
