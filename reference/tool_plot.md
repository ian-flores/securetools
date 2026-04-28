# Create a plot rendering tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that evaluates R plotting code and saves the result to a file.

## Usage

``` r
tool_plot(
  allowed_dirs,
  default_width = 8,
  default_height = 6,
  max_file_size = "5MB",
  max_calls = NULL,
  default_dpi = 150
)
```

## Arguments

- allowed_dirs:

  Character vector of directories the tool can write to.

- default_width:

  Default plot width in inches. Default 8.

- default_height:

  Default plot height in inches. Default 6.

- max_file_size:

  Maximum output file size. Default `"5MB"`.

- max_calls:

  Maximum invocations. `NULL` means unlimited.

- default_dpi:

  Default resolution in dots per inch for raster formats (png, jpg).
  Default 150.

## Value

A `securer_tool` object.

## Details

The plot tool evaluates R plotting code in a restricted environment.
Before evaluation, an AST walk validates that only allowed functions are
called, preventing arbitrary code execution. The following categories of
functions are permitted:

- **Graphics**: `plot`, `lines`, `points`, `abline`, `hist`, `barplot`,
  `boxplot`, `curve`, `title`, `legend`, `axis`, `mtext`, `text`, `par`,
  `grid`, `segments`, `arrows`, `polygon`, `rect`, `symbols`, `pie`,
  `pairs`, `heatmap`, `image`, `contour`, `persp`, `stripchart`,
  `dotchart`, `stars`, `sunflowerplot`, `coplot`, `cdplot`,
  `fourfoldplot`, `mosaicplot`, `assocplot`, `smoothScatter`,
  `spineplot`, `stem`

- **Helpers**: mathematical functions (`sqrt`, `log`, `exp`, etc.),
  string functions (`paste`, `sprintf`, etc.), and statistical
  distributions (`dnorm`, `rnorm`, etc.)

- **Data manipulation**: `data.frame`, `list`, `matrix`, `lapply`,
  `sapply`, `subset`, `with`, and others

- **Operators**: arithmetic, comparison, and logical operators

- **Flow control**: `if`, `for`, `while`, `{`, assignment

Supported output formats: png, pdf, svg, jpg/jpeg. The format is
auto-detected from the file extension by default.

## See also

[`securer_tool`](https://ian-flores.github.io/securer/reference/securer_tool.html)

Other tool factories:
[`tool_calculator()`](https://ian-flores.github.io/securetools/reference/tool_calculator.md),
[`tool_data_profile()`](https://ian-flores.github.io/securetools/reference/tool_data_profile.md),
[`tool_fetch_url()`](https://ian-flores.github.io/securetools/reference/tool_fetch_url.md),
[`tool_query_sql()`](https://ian-flores.github.io/securetools/reference/tool_query_sql.md),
[`tool_r_help()`](https://ian-flores.github.io/securetools/reference/tool_r_help.md),
[`tool_read_file()`](https://ian-flores.github.io/securetools/reference/tool_read_file.md),
[`tool_write_file()`](https://ian-flores.github.io/securetools/reference/tool_write_file.md)

## Examples

``` r
# \donttest{
plt <- tool_plot(allowed_dirs = tempdir())
# Basic scatter plot
plt@fn(
  path = file.path(tempdir(), "scatter.png"),
  plot_code = "plot(1:10, (1:10)^2, main = 'Example')"
)
#> $path
#> [1] "/tmp/RtmpvIG3uF/scatter.png"
#> 
#> $size
#> [1] 27235
#> 
#> $format
#> [1] "png"
#> 

# With custom dimensions and DPI
plt <- tool_plot(
  allowed_dirs = tempdir(),
  default_width = 10,
  default_height = 8,
  default_dpi = 300
)
# }
```
