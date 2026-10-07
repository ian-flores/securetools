# Create a plot rendering tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that runs base R plotting code and saves the plot to a file in the
folders you allow.

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

  Character vector of folders the tool can write to.

- default_width:

  Plot width in inches when the caller doesn't give one. Default 8.

- default_height:

  Plot height in inches when the caller doesn't give one. Default 6.

- max_file_size:

  The largest plot file the tool will write. Default `"5MB"`.

- max_calls:

  The most times the tool can be called. `NULL` means no limit.

- default_dpi:

  Resolution in dots per inch for png and jpg files. Default 150.

## Value

A `securer_tool` object.

## Details

Before running the code, the tool parses it and checks every function
call against a list of allowed functions:

- graphics: `plot`, `lines`, `points`, `abline`, `hist`, `barplot`,
  `boxplot`, `curve`, `title`, `legend`, `axis`, `mtext`, `text`, `par`,
  `grid`, `segments`, `arrows`, `polygon`, `rect`, `symbols`, `pie`,
  `pairs`, `heatmap`, `image`, `contour`, `persp`, `stripchart`,
  `dotchart`, `stars`, `sunflowerplot`, `coplot`, `cdplot`,
  `fourfoldplot`, `mosaicplot`, `assocplot`, `smoothScatter`,
  `spineplot`, `stem`

- helpers: math functions (`sqrt`, `log`, `exp`, and so on), string
  functions (`paste`, `sprintf`, and so on), and distributions (`dnorm`,
  `rnorm`, and so on)

- data: `data.frame`, `list`, `matrix`, `lapply`, `sapply`, `subset`,
  `with`, and others

- arithmetic, comparison, and logical operators

- `if`, `for`, `while`, `{`, and assignment

The code then runs in a new environment whose parent is the base
environment. Because of that, only
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) currently
works: functions from graphics such as
[`hist()`](https://rdrr.io/r/graphics/hist.html),
[`lines()`](https://rdrr.io/r/graphics/lines.html), and
[`barplot()`](https://rdrr.io/r/graphics/barplot.html) are on the list
but aren't found when the code runs.

This check does not stop arbitrary code yet.
[`do.call()`](https://rdrr.io/r/base/do.call.html) is on the list and
takes the function name as a string, so `do.call("system", list("ls"))`
gets through. Only give this tool to code that runs in a sandboxed
session.

The tool writes png, pdf, svg, and jpg files, and picks the format from
the file extension unless the caller passes `format`. The plot is drawn
to a temporary file, checked against `max_file_size`, and then copied to
the target path, which must be inside `allowed_dirs`.

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
#> [1] "/tmp/RtmpE0xQyS/scatter.png"
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
