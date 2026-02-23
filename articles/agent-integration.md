# Using securetools with Agents

## Overview

Building an AI agent that can act on the real world – reading files,
querying databases, calling APIs – requires combining an LLM’s reasoning
with executable tools. The challenge is that an LLM’s reasoning is
probabilistic and influenced by its inputs, which means any tool it can
call might be called in unexpected or adversarial ways. Agent frameworks
need to treat tool access as a security boundary, not just a convenience
layer.

securetools provides pre-built, security-hardened tools that plug
directly into [orchestr](https://github.com/ian-flores/orchestr) agents.
Each tool factory returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
object that orchestr’s `Agent` class converts to an ellmer tool
automatically when `secure = TRUE`. This means you get structural
security guarantees (path scoping, parameterized SQL, rate limiting)
without writing any security code yourself – the tools enforce
constraints by design.

This vignette shows how to wire securetools into single-agent ReAct
loops, multi-agent supervisor graphs, and mixed toolkits. For tool
factory basics, see
[`vignette("securetools")`](https://ian-flores.github.io/securetools/articles/securetools.md).
For orchestr fundamentals, see
[`vignette("quickstart", package = "orchestr")`](https://ian-flores.github.io/orchestr/articles/quickstart.html).

## Setup

``` r
library(securetools)
library(orchestr)
library(ellmer)

# Set your LLM provider API key
Sys.setenv(ANTHROPIC_API_KEY = "your-key-here")
```

## ReAct Agent with Tools

A ReAct (Reason + Act) agent is the foundational pattern for tool-using
LLMs. The agent receives a task, **reasons** about what to do next,
**acts** by calling a tool, **observes** the result, and then repeats
this cycle until it can formulate a final answer. This loop is powerful
but inherently risky: each iteration gives the LLM another chance to
call a tool, and a confused or manipulated agent can spiral into
unbounded tool use.

securetools makes ReAct loops safe by ensuring that every tool call
passes through parent-process validation before reaching the sandbox.
The LLM can reason freely, but its actions are constrained by the
structural guarantees of each tool.

The following diagram shows the execution flow of a ReAct agent with
securetools:

      ┌───────────────────────────────────────────────────┐
      │                   ReAct Loop                      │
      │                                                   │
      │   ┌──────────┐    ┌──────────┐    ┌───────────┐   │
      │   │          │    │          │    │           │   │
      │   │  Reason  │───>│   Act    │───>│  Observe  │   │
      │   │  (LLM)   │    │ (tool)   │    │ (result)  │   │
      │   │          │    │          │    │           │   │
      │   └──────────┘    └────┬─────┘    └─────┬─────┘   │
      │        ^               │                │         │
      │        │               v                │         │
      │        │        ┌──────────────┐        │         │
      │        │        │   Validate   │        │         │
      │        │        │  (parent R)  │        │         │
      │        │        │  - rate limit│        │         │
      │        │        │  - allow-list│        │         │
      │        │        │  - path check│        │         │
      │        │        └──────┬───────┘        │         │
      │        │               v                │         │
      │        │        ┌──────────────┐        │         │
      │        │        │   Execute    │        │         │
      │        │        │  (sandbox)   │────────┘         │
      │        │        └──────────────┘                  │
      │        │                                          │
      │        └──────────── loop ────────────────────────┘
      │                                                   │
      │   Done? ──yes──> Return final answer              │
      └───────────────────────────────────────────────────┘

Pass securetools to the
[`agent()`](https://ian-flores.github.io/orchestr/reference/Agent.html)
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

The supervisor pattern is the multi-agent equivalent of the principle of
least privilege. Instead of giving one agent all tools (calculator, file
I/O, SQL, HTTP), you create **specialist workers** that each carry only
the tools they need. A supervisor agent routes incoming requests to the
appropriate worker without itself having direct tool access.

This architecture has several security benefits. First, each worker gets
its own `SecureSession`, so rate limits, allowed directories, and domain
allow-lists are isolated per worker. A compromised or confused file
worker cannot suddenly start making HTTP requests. Second, the
supervisor sees only the high-level results from workers, not raw tool
outputs, which limits information leakage between agent boundaries.
Third, tool-level constraints can be tuned per-role: the data specialist
might have generous rate limits while the file writer is tightly capped.

      ┌─────────────────────────────────────────────────┐
      │                 Supervisor Agent                 │
      │           (no tools, routes only)                │
      │                                                  │
      │    "Read sales.csv, compute mean revenue"        │
      │                                                  │
      │         ┌──────────┬──────────┐                  │
      │         v          v          v                  │
      │   ┌───────────┐ ┌──────────┐ ┌──────────────┐   │
      │   │   File    │ │  Data    │ │  Research    │   │
      │   │ Specialist│ │Specialist│ │  Specialist  │   │
      │   │           │ │          │ │              │   │
      │   │ read_file │ │calculator│ │  fetch_url   │   │
      │   │ write_file│ │ profiler │ │              │   │
      │   └───────────┘ └──────────┘ └──────────────┘   │
      │                                                  │
      │   Each worker has its own SecureSession          │
      │   with isolated rate limits and allow-lists      │
      └─────────────────────────────────────────────────┘

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
that
[`supervisor_graph()`](https://ian-flores.github.io/orchestr/reference/supervisor_graph.html)
injects automatically. Workers each get their own `SecureSession`, so
tool-level constraints (allowed directories, rate limits) are isolated
per worker.

## Rate Limiting in Agent Loops

Rate limiting is especially critical in agent loops because the LLM
controls how many iterations occur. A ReAct agent that misunderstands a
task might call the calculator 500 times trying to “verify” an answer. A
research agent fetching URLs might follow links recursively, hammering
an external API. Without hard caps, agent loops can spiral into runaway
execution that wastes tokens, exhausts rate limits on external services,
or generates enormous output that overwhelms downstream processing.

securetools provides two complementary rate limiting mechanisms:

- **Lifetime caps** (`max_calls`): The total number of times a tool can
  be invoked across the entire session. Once hit, every subsequent call
  returns an error. This is your backstop against runaway loops.
- **Sliding window** (`max_calls_per_minute`): Limits burst frequency.
  Even if you allow 1000 lifetime calls, restricting to 10 per minute
  prevents overwhelming external services or disk I/O.

When a rate limit is reached, the tool returns a structured error
message to the LLM (not an R exception), giving the agent a chance to
adjust its strategy – for example, by summarizing what it has so far
instead of fetching more data.

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

Real-world agents often need capabilities beyond what securetools
provides out of the box. You can combine securetools factories with
custom
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
definitions in the same agent. All tools – both securetools and custom –
run inside the same secure session and benefit from the same sandbox
isolation.

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
- [`vignette("quickstart", package = "orchestr")`](https://ian-flores.github.io/orchestr/articles/quickstart.html)
  – agent and graph basics
- [`vignette("ellmer-integration", package = "securer")`](https://ian-flores.github.io/securer/articles/ellmer-integration.html)
  – low-level ellmer wiring
