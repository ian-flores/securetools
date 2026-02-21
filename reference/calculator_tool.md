# Create a calculator tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that evaluates mathematical expressions safely via AST validation.

## Usage

``` r
calculator_tool(max_calls = NULL)
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
[`data_profile_tool()`](https://ian-flores.github.io/securetools/reference/data_profile_tool.md),
[`fetch_url_tool()`](https://ian-flores.github.io/securetools/reference/fetch_url_tool.md),
[`plot_tool()`](https://ian-flores.github.io/securetools/reference/plot_tool.md),
[`query_sql_tool()`](https://ian-flores.github.io/securetools/reference/query_sql_tool.md),
[`r_help_tool()`](https://ian-flores.github.io/securetools/reference/r_help_tool.md),
[`read_file_tool()`](https://ian-flores.github.io/securetools/reference/read_file_tool.md),
[`write_file_tool()`](https://ian-flores.github.io/securetools/reference/write_file_tool.md)

## Examples

``` r
if (FALSE) { # \dontrun{
calc <- calculator_tool()
# Basic arithmetic
calc$fn(expression = "2 + 3 * 4")

# Math functions
calc$fn(expression = "sqrt(144) + log(exp(1))")

# With rate limiting
calc <- calculator_tool(max_calls = 100)
} # }
```
