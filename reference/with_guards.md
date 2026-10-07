# Add secureguard checks to a tool, in a pipe

The same as
[`guarded_tool()`](https://ian-flores.github.io/securetools/reference/guarded_tool.md),
named so it reads well in a pipe:
`tool_calculator() |> with_guards(input_guards = list(...))`.

## Usage

``` r
with_guards(tool, ...)
```

## Arguments

- tool:

  Same as
  [`guarded_tool()`](https://ian-flores.github.io/securetools/reference/guarded_tool.md).

- ...:

  Passed on to
  [`guarded_tool()`](https://ian-flores.github.io/securetools/reference/guarded_tool.md).

## Value

A new `securer_tool` with the checks added.
