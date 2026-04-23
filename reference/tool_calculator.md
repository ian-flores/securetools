# Create a calculator tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that evaluates mathematical expressions safely via AST validation.

## Usage

``` r
tool_calculator(max_calls = NULL)
```

## Arguments

- max_calls:

  Maximum number of invocations allowed. `NULL` (default) means
  unlimited.

## Value

A `securer_tool` object.

## Details

The calculator tool evaluates mathematical expressions in a restricted
environment. Only the following functions and operators are allowed:

- **Arithmetic**: `+`, `-`, `*`, `/`, `^`, `%%`, `%/%`

- **Math**: `sqrt`, `abs`, `log`, `log2`, `log10`, `exp`, `ceiling`,
  `floor`, `round`, `trunc`

- **Trigonometry**: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`

- **Aggregation**: `sum`, `mean`, `max`, `min`, `length`

- **Utilities**: `c`, `pi`

Expressions are first parsed and validated via an AST walk that rejects
any function call or symbol not on the allowlist. Evaluation then occurs
in a minimal environment containing only the allowed functions, with
[`emptyenv()`](https://rdrr.io/r/base/environment.html) as its parent to
prevent access to other R functionality.

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
