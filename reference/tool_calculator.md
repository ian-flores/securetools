# Create a calculator tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that evaluates a math expression. Anything other than arithmetic and a
short list of math functions is rejected before it runs.

## Usage

``` r
tool_calculator(max_calls = NULL)
```

## Arguments

- max_calls:

  The most times the tool can be called. `NULL` (the default) means no
  limit.

## Value

A `securer_tool` object.

## Details

These are the only functions and operators the calculator accepts:

- arithmetic: `+`, `-`, `*`, `/`, `^`, `%%`, `%/%`

- math: `sqrt`, `abs`, `log`, `log2`, `log10`, `exp`, `ceiling`,
  `floor`, `round`, `trunc`

- trigonometry: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`

- summaries: `sum`, `mean`, `max`, `min`, `length`

- `c` and `pi`

The expression must be a single expression. It is parsed, and every
function call and name in the parse tree is checked against the list
above before anything is evaluated. It is then evaluated in an
environment that holds only those functions and has
[`emptyenv()`](https://rdrr.io/r/base/environment.html) as its parent,
so nothing else in R is reachable.

## See also

[`securer_tool`](https://ian-flores.github.io/securer/reference/securer_tool.html)

Other tool factories:
[`tool_data_profile()`](https://ian-flores.github.io/securetools/reference/tool_data_profile.md),
[`tool_fetch_url()`](https://ian-flores.github.io/securetools/reference/tool_fetch_url.md),
[`tool_plot()`](https://ian-flores.github.io/securetools/reference/tool_plot.md),
[`tool_query_sql()`](https://ian-flores.github.io/securetools/reference/tool_query_sql.md),
[`tool_r_help()`](https://ian-flores.github.io/securetools/reference/tool_r_help.md),
[`tool_read_file()`](https://ian-flores.github.io/securetools/reference/tool_read_file.md),
[`tool_write_file()`](https://ian-flores.github.io/securetools/reference/tool_write_file.md)

## Examples

``` r
# \donttest{
calc <- tool_calculator()
# Basic arithmetic
calc@fn(expression = "2 + 3 * 4")
#> [1] 14

# Math functions
calc@fn(expression = "sqrt(144) + log(exp(1))")
#> [1] 13

# With rate limiting
calc <- tool_calculator(max_calls = 100)
# }
```
