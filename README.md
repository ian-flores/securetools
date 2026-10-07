# securetools

<!-- badges: start -->
[![R-CMD-check](https://github.com/ian-flores/securetools/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ian-flores/securetools/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/ian-flores/securetools/graph/badge.svg)](https://app.codecov.io/gh/ian-flores/securetools)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![pkgdown](https://github.com/ian-flores/securetools/actions/workflows/pkgdown.yaml/badge.svg)](https://ian-flores.github.io/securetools/)
<!-- badges: end -->

securetools has ready-made tools for LLM agents in R: a calculator, file
reading and writing, SQL queries, web requests, plots, and R help lookup.
Each tool comes with limits you set when you create it, such as which
folders it can touch, which tables it can query, or which websites it can
reach.

The tools are built for [securer](https://github.com/ian-flores/securer),
which runs an agent's R code in a separate, sandboxed process. When that
code calls a tool, the call goes back to your main R session, which checks
it against the limits and only then does the work.

The package is experimental, and function names may still change.

## Why use it

An agent with plain R can call `system()`, write to any path, and run any
SQL. Writing your own safe versions of these tools takes care: symlinks can
lead out of a folder, SQL strings can be injected into, and a URL can point
at a server on your internal network. securetools handles those cases so
you can give an agent useful tools without giving it the whole machine.

## Installation

```r
# install.packages("pak")
pak::pak("ian-flores/securetools")
```

## A quick look

```r
library(securetools)
library(securer)

# Each tool gets its limits up front
calc <- tool_calculator()
reader <- tool_read_file(allowed_dirs = "/data", max_file_size = "50MB")
sql <- tool_query_sql(conn = con, allowed_tables = c("users", "orders"))

# Code running in the session can call the tools like functions
session <- SecureSession$new(tools = list(calc, reader, sql))
session$execute('calculator(expression = "sqrt(144) + 2^3")')
#> [1] 20
session$close()
```

## The tools

| Function | What it does | Limits |
|---|---|---|
| `tool_calculator()` | Evaluates a math expression | Only arithmetic and math functions; anything else is rejected before it runs |
| `tool_data_profile()` | Summarizes a data frame | Samples rows from large data |
| `tool_read_file()` | Reads csv, json, txt, xlsx, parquet, or rds files | Allowed folders only, file size cap |
| `tool_write_file()` | Writes csv, json, txt, or rds files | Allowed folders only, size cap, no overwriting by default |
| `tool_query_sql()` | Runs a SELECT on one table | Allowed tables only; the agent never writes SQL |
| `tool_fetch_url()` | Makes a GET or HEAD request | Allowed domains only, no private IPs, rate limit |
| `tool_plot()` | Draws a base R plot to a file | Allowed folders only, output size cap |
| `tool_r_help()` | Returns an R help page as text | Allowed packages only |

Every tool also takes `max_calls`, a cap on how many times the agent can
call it.

## Adding secureguard checks

`guarded_tool()` runs [secureguard](https://github.com/ian-flores/secureguard)
checks on a tool's arguments before the tool runs, and on its result
afterwards. If a check fails, the tool call fails with an error. The
result is still an ordinary securer tool, so you use it the same way:

```r
library(securetools)
library(secureguard)

guarded <- guarded_tool(
  tool_calculator(),
  input_guards  = list(guard_prompt_injection()),
  output_guards = list(guard_output_secrets(action = "block"))
)

# `with_guards()` does the same thing and reads well in a pipe.
guarded <- tool_calculator() |>
  with_guards(input_guards = list(guard_prompt_injection()))
```

secureguard is optional. If it isn't installed, `guarded_tool()` stops
and tells you how to install it.

## How it works

You set the limits when you create a tool, for example
`tool_read_file(allowed_dirs = "/data")`. There is no version of a tool
without them.

The checks run in your main R session, not in the sandbox, so code in the
sandbox can't change or skip them.

File paths are resolved with `normalizePath()`, which follows symlinks,
before they are compared with the allowed folders. A symlink inside an
allowed folder that points somewhere else is caught.

The SQL tool takes a table name, a list of columns, and an optional filter.
It builds the query itself and passes the filter value as a parameter, so
there is no SQL string for the agent to tamper with.

The calculator parses the expression and checks every function and name in
it against a short list before evaluating it.

## Related packages

securetools is part of a small set of packages for running LLM agents in R
more safely:

- [securer](https://github.com/ian-flores/securer) runs agent code in a sandbox.
- [secureguard](https://github.com/ian-flores/secureguard) checks prompts, generated code, and outputs for things like prompt injection and leaked secrets.
- [securebench](https://github.com/ian-flores/securebench) measures how well your guardrails work. It complements [vitals](https://vitals.tidyverse.org/).

They build on Posit's tools rather than replacing them. For tracing, use
[ellmer](https://ellmer.tidyverse.org/)'s OpenTelemetry support through the
[otel](https://otel.r-lib.org/) package. securetools also records a span
for each tool call when otel tracing is on. For retrieval (RAG), use
[ragnar](https://github.com/tidyverse/ragnar).

## Learn more

- [Getting started](https://ian-flores.github.io/securetools/articles/securetools.html)
- [Using securetools with agents](https://ian-flores.github.io/securetools/articles/agent-integration.html)
- [Building a data analyst agent](https://ian-flores.github.io/securetools/articles/data-analyst-agent.html)
- [Function reference](https://ian-flores.github.io/securetools/reference/)
- A Plumber API example ships with the package: `system.file("examples", "plumber", package = "securetools")`

Found a bug or have an idea? [Open an issue](https://github.com/ian-flores/securetools/issues).

## License

MIT
