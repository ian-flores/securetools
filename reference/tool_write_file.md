# Create a file writing tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that writes files into the folders you allow, up to a size limit,
without overwriting existing files unless you say so.

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

  Character vector of folders the tool can write to.

- max_file_size:

  The largest file the tool will write. Default `"10MB"`.

- max_calls:

  The most times the tool can be called. `NULL` means no limit.

- overwrite:

  Whether the tool may replace a file that already exists. Default
  `FALSE`.

## Value

A `securer_tool` object.

## Details

The tool writes csv, json, txt, and rds files. It picks the format from
the file extension unless the caller passes `format`.

The `content` argument is declared as `"list"` in the tool schema,
because arguments are sent between processes as JSON and most R objects
arrive as lists. Pass a data frame for csv and json, a character vector
for txt, and any R object for rds.

The target's parent folder is resolved with
[`base::normalizePath()`](https://rdrr.io/r/base/normalizePath.html),
which follows symlinks, and must be inside one of `allowed_dirs`. The
data is written to a temporary file in the same folder first. If that
file is larger than `max_file_size`, nothing is written to the target.
Otherwise it is copied to the target, and the target's path is checked
again. If it now resolves outside `allowed_dirs`, the file is deleted
and the call fails.

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
