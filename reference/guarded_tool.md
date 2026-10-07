# Add secureguard checks to a tool

Wraps a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
so that every call runs secureguard guardrails on the arguments before
the tool runs, and on the result afterwards. The result is still a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
with the same name, description, and arguments, so you use it the same
way as the original.

## Usage

``` r
guarded_tool(tool, input_guards = list(), output_guards = list())
```

## Arguments

- tool:

  A `securer_tool`, usually from one of the `tool_*()` functions in this
  package. Any `securer_tool` works.

- input_guards:

  A list of secureguard guardrails of type `"input"` or `"code"`. The
  tool's arguments are turned into text and each guardrail must pass
  before the tool runs.

- output_guards:

  A list of secureguard guardrails of type `"output"`. The tool's result
  is turned into text with
  [`secureguard::output_to_text()`](https://ian-flores.github.io/secureguard/reference/output_to_text.html),
  and each guardrail must pass before the result is returned.

## Value

A new `securer_tool` with the checks added.

## Details

If a guardrail fails, the tool raises an error. Inside a securer session
that becomes a tool-call error, which ellmer passes back to the model as
an error result.

secureguard is only needed when you call `guarded_tool()`. If it isn't
installed, `guarded_tool()` stops with an error that says how to install
it. It never returns a tool without the checks.

## Examples

``` r
if (FALSE) { # \dontrun{
  calc <- tool_calculator()
  injection <- secureguard::guard_prompt_injection()
  secrets <- secureguard::guard_output_secrets(action = "block")
  guarded <- guarded_tool(
    calc,
    input_guards = list(injection),
    output_guards = list(secrets)
  )
} # }
```
