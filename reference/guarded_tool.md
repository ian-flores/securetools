# Wrap a securer_tool with input and output guardrails

Composes a tool from
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
with guardrails from secureguard. The returned object is itself a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
(same schema, same IPC contract) whose closure runs each invocation
through the supplied input guardrails, executes the underlying tool,
then runs the result through the output guardrails.

## Usage

``` r
guarded_tool(tool, input_guards = list(), output_guards = list())
```

## Arguments

- tool:

  A `securer_tool` object (typically from one of the `tool_*()`
  factories in this package, but any `securer_tool` works).

- input_guards:

  A list of `secureguard` input guardrails (type `"input"` or `"code"`).
  Each receives the stringified tool args and must pass for the call to
  proceed.

- output_guards:

  A list of `secureguard` output guardrails (type `"output"`). Each
  receives the tool's return value (coerced to text via
  [`secureguard::output_to_text`](https://ian-flores.github.io/secureguard/reference/output_to_text.html))
  and must pass for the result to be returned.

## Value

A new `securer_tool` object with guardrails applied.

## Details

Guardrail failures are translated into errors raised from the tool
closure; inside a securer session these surface as tool-call errors and
are returned to the LLM via ellmer's `ContentToolResult(error =)` shape.

Guardrails are applied lazily: if secureguard is not installed, calling
`guarded_tool()` errors with a clear installation hint rather than
silently skipping enforcement.

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
