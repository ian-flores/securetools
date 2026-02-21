# Create a file writing tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that writes data to files in specified directories with size limits and
overwrite protection.

## Usage

``` r
write_file_tool(
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
[`read_file_tool`](https://ian-flores.github.io/securetools/reference/read_file_tool.md)

Other tool factories:
[`calculator_tool()`](https://ian-flores.github.io/securetools/reference/calculator_tool.md),
[`data_profile_tool()`](https://ian-flores.github.io/securetools/reference/data_profile_tool.md),
[`fetch_url_tool()`](https://ian-flores.github.io/securetools/reference/fetch_url_tool.md),
[`plot_tool()`](https://ian-flores.github.io/securetools/reference/plot_tool.md),
[`query_sql_tool()`](https://ian-flores.github.io/securetools/reference/query_sql_tool.md),
[`r_help_tool()`](https://ian-flores.github.io/securetools/reference/r_help_tool.md),
[`read_file_tool()`](https://ian-flores.github.io/securetools/reference/read_file_tool.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tool <- write_file_tool(
  allowed_dirs = "/data/exports",
  max_file_size = "5MB",
  overwrite = FALSE
)
} # }
```
