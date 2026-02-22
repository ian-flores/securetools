# Using securetools with Agents

## Overview

securetools provides pre-built, security-hardened tools that plug
directly into [orchestr](https://github.com/ian-flores/orchestr) agents.
Each tool factory returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
object that orchestr’s `Agent` class converts to an ellmer tool
automatically when `secure = TRUE`.

This vignette shows how to wire securetools into single-agent ReAct
loops, multi-agent supervisor graphs, and mixed toolkits. For tool
factory basics, see
[`vignette("securetools")`](https://ian-flores.github.io/securetools/articles/securetools.md).
For orchestr fundamentals, see
`vignette("quickstart", package = "orchestr")`.

## Setup

``` r
library(securetools)
library(orchestr)
library(ellmer)

# Set your LLM provider API key
Sys.setenv(ANTHROPIC_API_KEY = "your-key-here")
```

## ReAct Agent with Tools

A ReAct agent reasons about a task, calls tools, observes results, and
repeats until it has an answer. Pass securetools to the `agent()`
constructor with `secure = TRUE` so tool calls run inside a securer
sandbox.

``` r
# Create security-scoped tools
calc <- calculator_tool()
reader <- read_file_tool(allowed_dirs = "/path/to/project/data")

# Build an agent with tools and secure execution
analyst <- agent(
  "analyst",
  chat = chat_anthropic(
    system_prompt = "You are a data analyst. Use your tools to answer questions."
  ),
  tools = list(calc, reader),
  secure = TRUE
)

# Wrap in a ReAct graph for state management
graph <- react_graph(analyst)

result <- graph$invoke(list(messages = list(
  "Read the file sales.csv from the data directory and calculate the total revenue."
)))
```

When `secure = TRUE`, orchestr creates a `SecureSession` behind the
scenes. Each `securer_tool` is converted to an ellmer tool definition
that executes inside the sandbox. Path scoping, AST validation, and rate
limits still apply at the parent-process level.

## Supervisor with Tool Specialists

A supervisor graph routes tasks to specialized worker agents. Each
worker carries its own set of tools. The supervisor decides which worker
to invoke based on the user’s request.

``` r
# Data agent: calculation and profiling
data_agent <- agent(
  "data_specialist",
  chat = chat_anthropic(
    system_prompt = paste(
      "You are a data specialist.",
      "Use the calculator for arithmetic and the profiler for data summaries."
    )
  ),
  tools = list(
    calculator_tool(),
    data_profile_tool(max_rows = 50000)
  ),
  secure = TRUE
)

# File agent: reading and writing
file_agent <- agent(
  "file_specialist",
  chat = chat_anthropic(
    system_prompt = paste(
      "You are a file specialist.",
      "Read and write files as requested.",
      "Always specify format = 'auto' when reading."
    )
  ),
  tools = list(
    read_file_tool(allowed_dirs = "/path/to/project/data"),
    write_file_tool(allowed_dirs = "/path/to/project/output")
  ),
  secure = TRUE
)

# Supervisor routes between specialists
supervisor <- agent(
  "supervisor",
  chat = chat_anthropic(
    system_prompt = paste(
      "You coordinate a team.",
      "Route data questions to the data specialist",
      "and file operations to the file specialist."
    )
  )
)

graph <- supervisor_graph(
  supervisor = supervisor,
  workers = list(
    data_specialist = data_agent,
    file_specialist = file_agent
  )
)

result <- graph$invoke(list(messages = list(
  "Read sales.csv, then calculate the mean of the revenue column."
)))
```

The supervisor does not need its own tools – it uses the `route` tool
that `supervisor_graph()` injects automatically. Workers each get their
own `SecureSession`, so tool-level constraints (allowed directories,
rate limits) are isolated per worker.

## Rate Limiting in Agent Loops

Agent loops can generate many tool calls. Use `max_calls` on tool
factories to set a hard cap that prevents runaway execution.

``` r
# Cap the calculator at 50 calls per agent session
calc <- calculator_tool(max_calls = 50)

# URL fetch with both lifetime and per-minute limits
fetcher <- fetch_url_tool(
  allowed_domains = c("api.github.com"),
  max_calls = 100,
  max_calls_per_minute = 10
)

researcher <- agent(
  "researcher",
  chat = chat_anthropic(
    system_prompt = "You fetch data from APIs and analyze results."
  ),
  tools = list(calc, fetcher),
  secure = TRUE
)

graph <- react_graph(researcher)
```

When a rate limit is hit, the tool returns an error message to the LLM,
which can then decide to stop or adjust its approach. This prevents both
runaway costs and accidental API abuse.

## Mixing securetools with Custom Tools

You can combine securetools factories with custom
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
definitions in the same agent. All tools run inside the same secure
session.

``` r
# A custom tool alongside securetools
timestamp_tool <- securer::securer_tool(
  name = "timestamp",
  description = "Return the current UTC timestamp.",
  fn = function() {
    format(Sys.time(), tz = "UTC", usetz = TRUE)
  },
  args = list()
)

# Mix custom + securetools
assistant <- agent(
  "assistant",
  chat = chat_anthropic(
    system_prompt = "You help with data tasks and can check the current time."
  ),
  tools = list(
    calculator_tool(),
    read_file_tool(allowed_dirs = "/path/to/data"),
    timestamp_tool
  ),
  secure = TRUE
)

graph <- react_graph(assistant)

result <- graph$invoke(list(messages = list(
  "What time is it? Also, what is 2^10?"
)))
```

Custom tools follow the same security model as securetools factories:
the `fn` runs in the parent process (not inside the sandbox), and
orchestr handles the ellmer conversion automatically.

## Next Steps

- [`vignette("securetools")`](https://ian-flores.github.io/securetools/articles/securetools.md)
  – tool factory reference and security model
- `vignette("quickstart", package = "orchestr")` – agent and graph
  basics
- [`vignette("ellmer-integration", package = "securer")`](https://ian-flores.github.io/securer/articles/ellmer-integration.html)
  – low-level ellmer wiring
