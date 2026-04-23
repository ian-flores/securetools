# Pipe-friendly alias for [`guarded_tool()`](https://ian-flores.github.io/securetools/reference/guarded_tool.md)

Lets you write
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

  Passed straight through to
  [`guarded_tool()`](https://ian-flores.github.io/securetools/reference/guarded_tool.md).

## Value

A new `securer_tool` object.
