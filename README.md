# securetools

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

## License

MIT
