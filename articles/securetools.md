# Getting Started with securetools

## Overview

securetools provides pre-built, security-hardened tool definitions for
use with [securer](https://github.com/ian-flores/securer). Each tool
factory returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
object with built-in constraints: path scoping, parameterized SQL,
domain allow-lists, size limits, and rate limiting.

## Installation

``` r
# install.packages("pak")
pak::pak("ian-flores/securetools")
```

## Quick Example

``` r
library(securetools)
library(securer)
```

### Calculator Tool

The calculator tool evaluates mathematical expressions safely via AST
validation. Only arithmetic operators, math functions, and numeric
literals are allowed – no variable access or arbitrary function calls.

``` r
calc <- calculator_tool()
session <- SecureSession$new(tools = list(calc))

session$execute('calculator(expression = "sqrt(144) + 2^3")')
#> [1] 20

# This is rejected -- system() is not an allowed function:
session$execute('calculator(expression = "system(\'whoami\')")')
#> Error: Function not allowed in calculator: `system`

session$close()
```

### File I/O Tools

Reading and writing files with path scoping and size limits:

``` r
# Only allow access to a specific directory
data_dir <- "/path/to/project/data"

reader <- read_file_tool(
  allowed_dirs = data_dir,
  max_file_size = "50MB",
  max_rows = 10000
)

writer <- write_file_tool(
  allowed_dirs = data_dir,
  max_file_size = "10MB",
  overwrite = FALSE
)

session <- SecureSession$new(tools = list(reader, writer))

# Read a CSV -- auto-detects format from extension
session$execute('
  data <- read_file(path = "/path/to/project/data/input.csv", format = "auto")
  head(data)
')

# Write results -- path traversal is blocked
session$execute('
  result <- data.frame(x = 1:5, y = letters[1:5])
  write_file(
    path = "/path/to/project/data/output.csv",
    content = result,
    format = "csv"
  )
')

session$close()
```

### SQL Query Tool

Structured queries with parameterized filters – SQL injection is
structurally impossible because no raw SQL is accepted:

``` r
library(DBI)
con <- dbConnect(RSQLite::SQLite(), "app.db")

sql_tool <- query_sql_tool(

  conn = con,
  allowed_tables = c("users", "orders"),
  max_rows = 1000
)

session <- SecureSession$new(tools = list(sql_tool))

# Query with filter -- uses parameterized query internally
session$execute('
  query_sql(
    table = "users",
    columns = "name, email",
    filter_column = "active",
    filter_value = "1"
  )
')

session$close()
dbDisconnect(con)
```

### URL Fetch Tool

HTTP GET/HEAD with domain allow-lists and rate limiting:

``` r
fetcher <- fetch_url_tool(
  allowed_domains = c("api.github.com", "*.githubusercontent.com"),
  max_response_size = "1MB",
  timeout_secs = 30,
  max_calls_per_minute = 10
)

session <- SecureSession$new(tools = list(fetcher))

session$execute('
  result <- fetch_url(url = "https://api.github.com/zen", method = "GET")
  result$body
')

session$close()
```

### Data Profiling

Compute summary statistics for data frames:

``` r
profiler <- data_profile_tool(max_rows = 100000)
session <- SecureSession$new(tools = list(profiler))

session$execute('
  profile <- data_profile(data = iris)
  profile$columns[[1]]  # Sepal.Length stats
')

session$close()
```

### Plot Tool

Render plots to files with path scoping:

``` r
plotter <- plot_tool(
  allowed_dirs = "/path/to/output",
  max_file_size = "5MB"
)

session <- SecureSession$new(tools = list(plotter))

session$execute('
  plot(
    path = "/path/to/output/chart.png",
    plot_code = "hist(rnorm(1000), main = \"Distribution\")",
    width = 8,
    height = 6
  )
')

session$close()
```

### R Help Lookup

The
[`r_help_tool()`](https://ian-flores.github.io/securetools/reference/r_help_tool.md)
provides safe access to R documentation:

``` r
help_tool <- r_help_tool(allowed_packages = c("base", "stats", "utils"))

session <- SecureSession$new(tools = list(help_tool))

# Look up documentation for a function
result <- session$call("r_help", topic = "mean", package = "base")
cat(result)

session$close()
```

The `allowed_packages` parameter restricts which packages can be
queried, preventing access to documentation of packages that may not be
appropriate.

## Security Model

Every tool enforces constraints at the **parent process** level, not in
the sandbox. This means even if the sandbox is somehow bypassed,
tool-level protections still hold: - **Path scoping**: symlinks are
resolved before checking allowed directories - **Parameterized SQL**:
structured interface prevents injection by design - **Domain
allow-lists**: URL validation before any HTTP request - **Size limits**:
checked after serialization (write) or before processing (read) - **Rate
limiting**: per-tool lifetime and/or sliding window limits - **AST
validation**: calculator expression safety via recursive AST walking

## Security Considerations

### Threat Model

securetools is designed to protect against an untrusted LLM agent
attempting to:

- **Read sensitive files**: Path validation with symlink resolution
  prevents directory traversal
- **Write to arbitrary locations**: Write paths are validated against
  allowed directories
- **Execute arbitrary code**: Calculator uses AST validation; plot tool
  restricts to plotting functions
- **Access internal services (SSRF)**: URL fetching validates protocols
  (HTTP/HTTPS only) and blocks private IPs
- **SQL injection**: Structured query interface with parameterized
  filters prevents raw SQL injection
- **Resource exhaustion**: Rate limiting and size limits constrain
  resource usage

### Known Limitations

- **TOCTOU races**: Between path validation and file I/O, a symlink
  could theoretically be swapped. Use `validate_written_path()` for
  post-write verification.
- **Rate limiting is per-process**: Limits reset if the R process
  restarts. For persistent rate limiting, use an external mechanism.
- **DNS rebinding**: The private IP check resolves DNS before the
  request, but sophisticated DNS rebinding attacks could theoretically
  bypass this.
- **Base R access in restricted environments**: The plot tool’s
  restricted environment still provides access to safe base R functions.
  The allowlist is comprehensive but may need updates for new R
  versions.

### Working with SecureSession

When tools are called through `SecureSession` IPC, all tool arguments
must be specified explicitly. The child process wrappers do not carry
default values from the tool factory. For example, always specify
`format = "auto"` even though it’s the default in direct usage.

## Rate Limiting

All tool factories accept `max_calls` for lifetime rate limiting:

``` r
# Allow only 100 calculator evaluations per session
calc <- calculator_tool(max_calls = 100)

# URL fetch with both lifetime and per-minute limits
fetcher <- fetch_url_tool(
  max_calls = 1000,
  max_calls_per_minute = 10
)
```

## Available Tools

| Tool         | Factory                                                                                          | Key Security Features                           |
|--------------|--------------------------------------------------------------------------------------------------|-------------------------------------------------|
| Calculator   | [`calculator_tool()`](https://ian-flores.github.io/securetools/reference/calculator_tool.md)     | AST validation, no code injection               |
| Data Profile | [`data_profile_tool()`](https://ian-flores.github.io/securetools/reference/data_profile_tool.md) | Row sampling for large data                     |
| Read File    | [`read_file_tool()`](https://ian-flores.github.io/securetools/reference/read_file_tool.md)       | Path scoping, size limits                       |
| Write File   | [`write_file_tool()`](https://ian-flores.github.io/securetools/reference/write_file_tool.md)     | Path scoping, size limits, overwrite protection |
| SQL Query    | [`query_sql_tool()`](https://ian-flores.github.io/securetools/reference/query_sql_tool.md)       | Table allow-list, parameterized queries         |
| URL Fetch    | [`fetch_url_tool()`](https://ian-flores.github.io/securetools/reference/fetch_url_tool.md)       | Domain allow-list, rate limiting                |
| Plot         | [`plot_tool()`](https://ian-flores.github.io/securetools/reference/plot_tool.md)                 | Path scoping, output size limits                |
| R Help       | [`r_help_tool()`](https://ian-flores.github.io/securetools/reference/r_help_tool.md)             | Package allow-list                              |
