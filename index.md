# securetools

> **Note:** Experimental release. APIs may change before the 1.0
> stabilization — track the lifecycle badge above for the current tier.

Security-hardened tool definitions for R LLM agents. Pre-built
[securer](https://github.com/ian-flores/securer) tool factories with
path scoping, parameterized SQL, domain allow-lists, size limits, and
rate limiting.

## Why securetools?

LLMs can call [`system()`](https://rdrr.io/r/base/system.html), write to
any path, and run arbitrary SQL. securetools provides pre-built,
security-hardened tool wrappers that enforce sandboxing, path
restrictions, and query validation – so you can give AI agents real
capabilities without giving them the keys to the kingdom.

## Part of the secure-r-dev Packages

securetools is one of four packages for building governed AI agents in
R:

                     ┌─────────────┐
                     │   securer    │  Sandboxed execution + tool-call IPC
                     └──────┬───────┘
                ┌───────────┴───────────┐
                │                       │
        ┌───────▼────────┐       ┌──────▼───────┐
        │>>> securetools<<<│◄──────┤ secureguard  │
        └────────────────┘ guards └──────┬───────┘
                                         │
                                  ┌──────▼───────┐
                                  │ securebench  │  (evaluation)
                                  └──────────────┘

securetools composes securer and secureguard: it provides pre-built,
security-hardened tool definitions that plug directly into securer
sessions, and (via
[`guarded_tool()`](https://ian-flores.github.io/securetools/reference/guarded_tool.md))
wraps them with secureguard guardrails, giving agents safe access to
files, SQL, URLs, and computation.

| Package | Role |
|----|----|
| [securer](https://github.com/ian-flores/securer) | Sandboxed R execution with tool-call IPC |
| [securetools](https://github.com/ian-flores/securetools) | Pre-built security-hardened tool definitions |
| [secureguard](https://github.com/ian-flores/secureguard) | Input/code/output guardrails (injection, PII, secrets) |
| [securebench](https://github.com/ian-flores/securebench) | Guardrail benchmarking with precision/recall/F1 metrics |

Observability is built on OpenTelemetry: securetools emits optional
tool-call spans via the [otel](https://otel.r-lib.org/) package, use
[ellmer](https://ellmer.tidyverse.org/)’s native OpenTelemetry support
to trace the LLM side of your agent, and
[ragnar](https://ragnar.tidyverse.org/) for retrieval-augmented context.
For graph-based agent orchestration on top of these packages, see
[orchestr](https://github.com/ian-flores/orchestr).

## Installation

``` r

# install.packages("pak")
pak::pak("ian-flores/securetools")
```

## Quick Start

``` r

library(securetools)
library(securer)

# Create tools with security constraints
calc <- tool_calculator()
reader <- tool_read_file(allowed_dirs = "/data", max_file_size = "50MB")
sql <- tool_query_sql(conn = con, allowed_tables = c("users", "orders"))

# Use with SecureSession
session <- SecureSession$new(tools = list(calc, reader, sql))
session$execute('calculator(expression = "sqrt(144) + 2^3")')
#> [1] 20
session$close()
```

## Available Tools

| Tool | Factory | Security Features |
|----|----|----|
| Calculator | [`tool_calculator()`](https://ian-flores.github.io/securetools/reference/tool_calculator.md) | AST validation, no code injection |
| Data Profile | [`tool_data_profile()`](https://ian-flores.github.io/securetools/reference/tool_data_profile.md) | Row sampling for large data |
| Read File | [`tool_read_file()`](https://ian-flores.github.io/securetools/reference/tool_read_file.md) | Path scoping, size limits |
| Write File | [`tool_write_file()`](https://ian-flores.github.io/securetools/reference/tool_write_file.md) | Path scoping, overwrite protection |
| SQL Query | [`tool_query_sql()`](https://ian-flores.github.io/securetools/reference/tool_query_sql.md) | Table allow-list, parameterized queries |
| URL Fetch | [`tool_fetch_url()`](https://ian-flores.github.io/securetools/reference/tool_fetch_url.md) | Domain allow-list, rate limiting |
| Plot | [`tool_plot()`](https://ian-flores.github.io/securetools/reference/tool_plot.md) | Path scoping, output size limits |
| R Help | [`tool_r_help()`](https://ian-flores.github.io/securetools/reference/tool_r_help.md) | Package allow-list |

## Composing with secureguard

[`guarded_tool()`](https://ian-flores.github.io/securetools/reference/guarded_tool.md)
wraps any `securer_tool` with input/output guardrails from
[secureguard](https://github.com/ian-flores/secureguard). The returned
object is itself a `securer_tool` (same schema, same IPC contract) whose
closure runs each invocation through the guards before and after the
underlying function. Guardrail failures surface as tool-call errors:

``` r

library(securetools)
library(secureguard)

guarded <- guarded_tool(
  tool_calculator(),
  input_guards  = list(guard_prompt_injection()),
  output_guards = list(guard_output_secrets(action = "block"))
)

# `with_guards()` is the pipe-friendly alias.
guarded <- tool_calculator() |>
  with_guards(input_guards = list(guard_prompt_injection()))
```

secureguard is a soft dependency (Suggests); calling
[`guarded_tool()`](https://ian-flores.github.io/securetools/reference/guarded_tool.md)
without secureguard installed errors with a clear install hint.

## Design Principles

- **Factory functions**: `tool_read_file(allowed_dirs = "/data")` forces
  explicit security configuration
- **Parent-side enforcement**: Tool constraints run in the host process,
  not the sandbox. Even sandbox bypass leaves tool protections intact
- **No raw SQL**: Structured query interface makes injection
  structurally impossible
- **Symlink resolution**:
  [`normalizePath()`](https://rdrr.io/r/base/normalizePath.html) before
  path prefix check prevents symlink escape
- **AST walking**: Calculator validates expression trees, not strings

## Documentation

- [`vignette("securetools")`](https://ian-flores.github.io/securetools/articles/securetools.md)
  – Getting started: tool factories, security configuration, and usage
  with securer sessions
- [`vignette("agent-integration")`](https://ian-flores.github.io/securetools/articles/agent-integration.md)
  – End-to-end examples wiring securetools into LLM agent workflows
- [`vignette("data-analyst-agent")`](https://ian-flores.github.io/securetools/articles/data-analyst-agent.md)
  – Building a governed data analyst agent with securer + secureguard +
  securetools
- `system.file("examples", package = "securetools")` – Runnable
  examples, including a Plumber REST API with guarded chat and sandboxed
  execution
- [pkgdown site](https://ian-flores.github.io/securetools/) – Full API
  reference and rendered vignettes

## Contributing

Found a bug or have a feature request? Please [file an
issue](https://github.com/ian-flores/securetools/issues) on GitHub.
Contributions via pull requests are welcome.

## License

MIT
