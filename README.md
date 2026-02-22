# securetools

<!-- badges: start -->
[![R-CMD-check](https://github.com/ian-flores/securetools/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ian-flores/securetools/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/ian-flores/securetools/graph/badge.svg)](https://app.codecov.io/gh/ian-flores/securetools)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![pkgdown](https://github.com/ian-flores/securetools/actions/workflows/pkgdown.yaml/badge.svg)](https://ian-flores.github.io/securetools/)
<!-- badges: end -->

> [!CAUTION]
> **Alpha software.** This package is part of a broader effort by [Ian Flores Siaca](https://github.com/ian-flores) to develop proper AI infrastructure for the R ecosystem. It is under active development and should **not** be used in production until an official release is published. APIs may change without notice.

Security-hardened tool definitions for R LLM agents. Pre-built
[securer](https://github.com/ian-flores/securer) tool factories with
path scoping, parameterized SQL, domain allow-lists, size limits, and rate
limiting.

## Why securetools?

LLMs can call `system()`, write to any path, and run arbitrary SQL.
securetools provides pre-built, security-hardened tool wrappers that enforce
sandboxing, path restrictions, and query validation -- so you can give AI
agents real capabilities without giving them the keys to the kingdom.

## Part of the secure-r-dev Ecosystem

securetools is part of a 7-package ecosystem for building governed AI agents in R:

```
                    ┌─────────────┐
                    │   securer    │
                    └──────┬──────┘
          ┌────────────────┼─────────────────┐
          │                │                  │
  ┌───────▼────────┐  ┌───▼──────────┐  ┌───▼──────────────┐
  │>>> securetools<<<│  │ secureguard  │  │  securecontext   │
  └───────┬────────┘  └───┬──────────┘  └───┬──────────────┘
          └────────────────┼─────────────────┘
                    ┌──────▼───────┐
                    │   orchestr   │
                    └──────┬───────┘
          ┌────────────────┼─────────────────┐
          │                                  │
   ┌──────▼──────┐                    ┌──────▼──────┐
   │ securetrace  │                   │ securebench  │
   └─────────────┘                    └─────────────┘
```

securetools provides pre-built, security-hardened tool definitions that plug directly into securer sessions. It sits in the middle layer alongside secureguard and securecontext, giving agents safe access to files, SQL, URLs, and computation.

| Package | Role |
|---------|------|
| [securer](https://github.com/ian-flores/securer) | Sandboxed R execution with tool-call IPC |
| [securetools](https://github.com/ian-flores/securetools) | Pre-built security-hardened tool definitions |
| [secureguard](https://github.com/ian-flores/secureguard) | Input/code/output guardrails (injection, PII, secrets) |
| [orchestr](https://github.com/ian-flores/orchestr) | Graph-based agent orchestration |
| [securecontext](https://github.com/ian-flores/securecontext) | Document chunking, embeddings, RAG retrieval |
| [securetrace](https://github.com/ian-flores/securetrace) | Structured tracing, token/cost accounting, JSONL export |
| [securebench](https://github.com/ian-flores/securebench) | Guardrail benchmarking with precision/recall/F1 metrics |

## Installation

```r
# install.packages("pak")
pak::pak("ian-flores/securetools")
```

## Quick Start

```r
library(securetools)
library(securer)

# Create tools with security constraints
calc <- calculator_tool()
reader <- read_file_tool(allowed_dirs = "/data", max_file_size = "50MB")
sql <- query_sql_tool(conn = con, allowed_tables = c("users", "orders"))

# Use with SecureSession
session <- SecureSession$new(tools = list(calc, reader, sql))
session$execute('calculator(expression = "sqrt(144) + 2^3")')
#> [1] 20
session$close()
```

## Available Tools

| Tool | Factory | Security Features |
|------|---------|-------------------|
| Calculator | `calculator_tool()` | AST validation, no code injection |
| Data Profile | `data_profile_tool()` | Row sampling for large data |
| Read File | `read_file_tool()` | Path scoping, size limits |
| Write File | `write_file_tool()` | Path scoping, overwrite protection |
| SQL Query | `query_sql_tool()` | Table allow-list, parameterized queries |
| URL Fetch | `fetch_url_tool()` | Domain allow-list, rate limiting |
| Plot | `plot_tool()` | Path scoping, output size limits |
| R Help | `r_help_tool()` | Package allow-list |

## Design Principles

- **Factory functions**: `read_file_tool(allowed_dirs = "/data")` forces
  explicit security configuration
- **Parent-side enforcement**: Tool constraints run in the host process,
  not the sandbox. Even sandbox bypass leaves tool protections intact
- **No raw SQL**: Structured query interface makes injection structurally
  impossible
- **Symlink resolution**: `normalizePath()` before path prefix check
  prevents symlink escape
- **AST walking**: Calculator validates expression trees, not strings

## Documentation

- `vignette("securetools")` -- Getting started: tool factories, security
  configuration, and usage with securer sessions
- `vignette("agent-integration")` -- End-to-end examples wiring securetools
  into LLM agent workflows
- [pkgdown site](https://ian-flores.github.io/securetools/) -- Full API
  reference and rendered vignettes

## Contributing

Found a bug or have a feature request? Please
[file an issue](https://github.com/ian-flores/securetools/issues) on GitHub.
Contributions via pull requests are welcome.

## License

MIT
