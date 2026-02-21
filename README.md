# securetools

> [!CAUTION]
> **Alpha software.** This package is part of a broader effort by [Ian Flores Siaca](https://github.com/ian-flores) to develop proper AI infrastructure for the R ecosystem. It is under active development and should **not** be used in production until an official release is published. APIs may change without notice.

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/ian-flores/securetools/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ian-flores/securetools/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Security-hardened tool definitions for R LLM agents. Pre-built
[securer](https://github.com/ian-flores/securer) tool factories with
path scoping, parameterized SQL, domain allow-lists, size limits, and rate
limiting.

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

## Getting Started

See the [Getting Started vignette](https://ian-flores.github.io/securetools/articles/securetools.html)
for detailed usage examples of each tool and an overview of the security model.
Full documentation is available at the [pkgdown site](https://ian-flores.github.io/securetools/).

## Contributing

Found a bug or have a feature request? Please
[file an issue](https://github.com/ian-flores/securetools/issues) on GitHub.
Contributions via pull requests are welcome.

## License

MIT
