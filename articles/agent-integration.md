# Using securetools with agents

## Overview

An agent decides for itself when to call a tool and with what arguments.
Its choices depend on everything it has read, including text an attacker
may have planted. So any tool you give it can end up being called in
ways you didn’t plan for, and the tool itself has to enforce the limits.

This vignette shows securetools inside
[orchestr](https://github.com/ian-flores/orchestr) agents. Each
`tool_*()` function returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html),
and orchestr’s
[`agent()`](https://ian-flores.github.io/orchestr/reference/Agent.html)
turns it into an ellmer tool when you set `secure = TRUE`. The limits
(allowed folders, allowed tables, call caps) come with the tool, so you
don’t write any checking code yourself.

The examples cover a single agent in a ReAct loop, a supervisor with
specialist workers, call limits, and custom tools next to the built-in
ones. For the tools themselves, see
[`vignette("securetools")`](https://ian-flores.github.io/securetools/articles/securetools.md).
For orchestr, see
[`vignette("quickstart", package = "orchestr")`](https://ian-flores.github.io/orchestr/articles/quickstart.html).

## Setup

``` r

library(securetools)
library(orchestr)
library(ellmer)

# Set your LLM provider API key
Sys.setenv(ANTHROPIC_API_KEY = "your-key-here")
```

## A ReAct agent with tools

ReAct (reason, then act) is the usual loop for an agent with tools. The
model reads the task, decides what to do, calls a tool, looks at the
result, and repeats until it has an answer. Every turn of the loop is
another tool call, and an agent that is confused or has been manipulated
can keep going for a long time.

With securetools, every call is checked in the parent R process before
the tool does anything. The model can ask for whatever it likes; the
tool only does what its limits allow.

Here is how one turn of the loop runs:

![](data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIGFyaWEtbGFiZWw9IlJlYXNvbiwgYWN0LCB2YWxpZGF0ZSwgZXhlY3V0ZSwgb2JzZXJ2ZSwgdGhlbiBsb29wIHVudGlsIGRvbmUgYW5kIHJldHVybiB0aGUgYW5zd2VyIiB2aWV3Ym94PSIwIDAgOTAwIDI3MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZGVmcz48bWFya2VyIGlkPSJyeC1hcnJvdyIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNyIgbWFya2VyaGVpZ2h0PSI3IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTEgMUw5IDVMMSA5IiBmaWxsPSJub25lIiBzdHJva2U9IiMyYjFmMTIiIHN0cm9rZS13aWR0aD0iMSIgLz48L21hcmtlcj48cGF0dGVybiBpZD0icngtaGF0Y2giIHdpZHRoPSI2IiBoZWlnaHQ9IjYiIHBhdHRlcm51bml0cz0idXNlclNwYWNlT25Vc2UiIHBhdHRlcm50cmFuc2Zvcm09InJvdGF0ZSg0NSkiPjxsaW5lIHgxPSIwIiB5MT0iMCIgeDI9IjAiIHkyPSI2IiBzdHJva2U9IiNiZjVhMzYiIHN0cm9rZS13aWR0aD0iMC42IiBvcGFjaXR5PSIwLjU1Ij48L2xpbmU+PC9wYXR0ZXJuPjwvZGVmcz48cmVjdCB4PSIyMCIgeT0iMTEyIiB3aWR0aD0iMTIwIiBoZWlnaHQ9IjY0IiBmaWxsPSJub25lIiBzdHJva2U9IiMyYjFmMTIiIHN0cm9rZS13aWR0aD0iMC43NSIgLz48dGV4dCB4PSI4MC4wIiB5PSIxMzQuMCIgZm9udC1mYW1pbHk9IlNwYWNlIE1vbm8sIHVpLW1vbm9zcGFjZSwgbW9ub3NwYWNlIiBmb250LXNpemU9IjEwLjUiIGZpbGw9IiMyYjFmMTIiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI3MDAiIGxldHRlci1zcGFjaW5nPSIxLjIiPlJFQVNPTjwvdGV4dD48dGV4dCB4PSI4MC4wIiB5PSIxNDguMCIgZm9udC1mYW1pbHk9IlNwYWNlIE1vbm8sIHVpLW1vbm9zcGFjZSwgbW9ub3NwYWNlIiBmb250LXNpemU9IjkiIGZpbGw9IiM2YjU2MzgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI0MDAiIGxldHRlci1zcGFjaW5nPSIwLjQiPnRoZSBtb2RlbCBkZWNpZGVzPC90ZXh0Pjx0ZXh0IHg9IjgwLjAiIHk9IjE2MS4wIiBmb250LWZhbWlseT0iU3BhY2UgTW9ubywgdWktbW9ub3NwYWNlLCBtb25vc3BhY2UiIGZvbnQtc2l6ZT0iOSIgZmlsbD0iIzZiNTYzOCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjQwMCIgbGV0dGVyLXNwYWNpbmc9IjAuNCI+d2hhdCB0byBkbyBuZXh0PC90ZXh0PjxwYXRoIGQ9Ik0xNDAgMTQ0LjBIMTc2IiBmaWxsPSJub25lIiBzdHJva2U9IiMyYjFmMTIiIHN0cm9rZS13aWR0aD0iMC43NSIgbWFya2VyLWVuZD0idXJsKCNyeC1hcnJvdykiIC8+PHJlY3QgeD0iMTc4IiB5PSIxMTIiIHdpZHRoPSIxMjAiIGhlaWdodD0iNjQiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzJiMWYxMiIgc3Ryb2tlLXdpZHRoPSIwLjc1IiAvPjx0ZXh0IHg9IjIzOC4wIiB5PSIxMzQuMCIgZm9udC1mYW1pbHk9IlNwYWNlIE1vbm8sIHVpLW1vbm9zcGFjZSwgbW9ub3NwYWNlIiBmb250LXNpemU9IjEwLjUiIGZpbGw9IiMyYjFmMTIiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI3MDAiIGxldHRlci1zcGFjaW5nPSIxLjIiPkFDVDwvdGV4dD48dGV4dCB4PSIyMzguMCIgeT0iMTQ4LjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSI5IiBmaWxsPSIjNmI1NjM4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNDAwIiBsZXR0ZXItc3BhY2luZz0iMC40Ij5pdCBhc2tzIGZvcjwvdGV4dD48dGV4dCB4PSIyMzguMCIgeT0iMTYxLjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSI5IiBmaWxsPSIjNmI1NjM4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNDAwIiBsZXR0ZXItc3BhY2luZz0iMC40Ij5hIHRvb2wgY2FsbDwvdGV4dD48cGF0aCBkPSJNMjk4IDE0NC4wSDMzNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMmIxZjEyIiBzdHJva2Utd2lkdGg9IjAuNzUiIG1hcmtlci1lbmQ9InVybCgjcngtYXJyb3cpIiAvPjxyZWN0IHg9IjMzNiIgeT0iMTAyIiB3aWR0aD0iMTUwIiBoZWlnaHQ9Ijg0IiBmaWxsPSJub25lIiBzdHJva2U9IiMyYjFmMTIiIHN0cm9rZS13aWR0aD0iMC43NSIgLz48dGV4dCB4PSI0MTEuMCIgeT0iMTI3LjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSIxMC41IiBmaWxsPSIjMmIxZjEyIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNzAwIiBsZXR0ZXItc3BhY2luZz0iMS4yIj5WQUxJREFURTwvdGV4dD48dGV4dCB4PSI0MTEuMCIgeT0iMTQxLjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSI5IiBmaWxsPSIjNmI1NjM4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNDAwIiBsZXR0ZXItc3BhY2luZz0iMC40Ij5yYXRlIGxpbWl0PC90ZXh0Pjx0ZXh0IHg9IjQxMS4wIiB5PSIxNTQuMCIgZm9udC1mYW1pbHk9IlNwYWNlIE1vbm8sIHVpLW1vbm9zcGFjZSwgbW9ub3NwYWNlIiBmb250LXNpemU9IjkiIGZpbGw9IiM2YjU2MzgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI0MDAiIGxldHRlci1zcGFjaW5nPSIwLjQiPmFsbG93LWxpc3Q8L3RleHQ+PHRleHQgeD0iNDExLjAiIHk9IjE2Ny4wIiBmb250LWZhbWlseT0iU3BhY2UgTW9ubywgdWktbW9ub3NwYWNlLCBtb25vc3BhY2UiIGZvbnQtc2l6ZT0iOSIgZmlsbD0iIzZiNTYzOCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjQwMCIgbGV0dGVyLXNwYWNpbmc9IjAuNCI+cGF0aCBjaGVjazwvdGV4dD48cGF0aCBkPSJNNDg2IDE0NC4wSDUyMiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMmIxZjEyIiBzdHJva2Utd2lkdGg9IjAuNzUiIG1hcmtlci1lbmQ9InVybCgjcngtYXJyb3cpIiAvPjxyZWN0IHg9IjUyNCIgeT0iMTEyIiB3aWR0aD0iMTIwIiBoZWlnaHQ9IjY0IiBmaWxsPSJub25lIiBzdHJva2U9IiMyYjFmMTIiIHN0cm9rZS13aWR0aD0iMC43NSIgLz48dGV4dCB4PSI1ODQuMCIgeT0iMTQxLjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSIxMC41IiBmaWxsPSIjMmIxZjEyIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNzAwIiBsZXR0ZXItc3BhY2luZz0iMS4yIj5FWEVDVVRFPC90ZXh0Pjx0ZXh0IHg9IjU4NC4wIiB5PSIxNTUuMCIgZm9udC1mYW1pbHk9IlNwYWNlIE1vbm8sIHVpLW1vbm9zcGFjZSwgbW9ub3NwYWNlIiBmb250LXNpemU9IjkiIGZpbGw9IiM2YjU2MzgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI0MDAiIGxldHRlci1zcGFjaW5nPSIwLjQiPnRoZSB0b29sIHJ1bnM8L3RleHQ+PHBhdGggZD0iTTY0NCAxNDQuMEg2ODAiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzJiMWYxMiIgc3Ryb2tlLXdpZHRoPSIwLjc1IiBtYXJrZXItZW5kPSJ1cmwoI3J4LWFycm93KSIgLz48cmVjdCB4PSI2ODIiIHk9IjExMiIgd2lkdGg9IjEyMCIgaGVpZ2h0PSI2NCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMmIxZjEyIiBzdHJva2Utd2lkdGg9IjAuNzUiIC8+PHRleHQgeD0iNzQyLjAiIHk9IjEzNC4wIiBmb250LWZhbWlseT0iU3BhY2UgTW9ubywgdWktbW9ub3NwYWNlLCBtb25vc3BhY2UiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iIzJiMWYxMiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjcwMCIgbGV0dGVyLXNwYWNpbmc9IjEuMiI+T0JTRVJWRTwvdGV4dD48dGV4dCB4PSI3NDIuMCIgeT0iMTQ4LjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSI5IiBmaWxsPSIjNmI1NjM4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNDAwIiBsZXR0ZXItc3BhY2luZz0iMC40Ij50aGUgcmVzdWx0IGdvZXM8L3RleHQ+PHRleHQgeD0iNzQyLjAiIHk9IjE2MS4wIiBmb250LWZhbWlseT0iU3BhY2UgTW9ubywgdWktbW9ub3NwYWNlLCBtb25vc3BhY2UiIGZvbnQtc2l6ZT0iOSIgZmlsbD0iIzZiNTYzOCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjQwMCIgbGV0dGVyLXNwYWNpbmc9IjAuNCI+YmFjayB0byB0aGUgbW9kZWw8L3RleHQ+PHBhdGggZD0iTTc0MiAxNzZWMjUwSDgwVjE3OCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMmIxZjEyIiBzdHJva2Utd2lkdGg9IjAuNzUiIG1hcmtlci1lbmQ9InVybCgjcngtYXJyb3cpIiBzdHJva2UtZGFzaGFycmF5PSIzIDMiIC8+PHRleHQgeD0iNDExIiB5PSIyNDQiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSI5IiBmaWxsPSIjNmI1NjM4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNDAwIiBsZXR0ZXItc3BhY2luZz0iMiI+TE9PUDwvdGV4dD48cGF0aCBkPSJNODAgMTEyVjQ0SDY3NiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMmIxZjEyIiBzdHJva2Utd2lkdGg9IjAuNzUiIG1hcmtlci1lbmQ9InVybCgjcngtYXJyb3cpIiAvPjx0ZXh0IHg9IjkwIiB5PSIzNiIgZm9udC1mYW1pbHk9IlNwYWNlIE1vbm8sIHVpLW1vbm9zcGFjZSwgbW9ub3NwYWNlIiBmb250LXNpemU9IjkuNSIgZmlsbD0iIzZiNTYzOCIgdGV4dC1hbmNob3I9InN0YXJ0IiBmb250LXdlaWdodD0iNDAwIiBsZXR0ZXItc3BhY2luZz0iMC40Ij5kb25lPC90ZXh0PjxyZWN0IHg9IjY3OCIgeT0iMjQiIHdpZHRoPSIyMDAiIGhlaWdodD0iNDAiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2JmNWEzNiIgc3Ryb2tlLXdpZHRoPSIwLjc1IiAvPjx0ZXh0IHg9Ijc3OC4wIiB5PSI0OC4wIiBmb250LWZhbWlseT0iU3BhY2UgTW9ubywgdWktbW9ub3NwYWNlLCBtb25vc3BhY2UiIGZvbnQtc2l6ZT0iMTAuNSIgZmlsbD0iI2JmNWEzNiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjcwMCIgbGV0dGVyLXNwYWNpbmc9IjEuMiI+UkVUVVJOIFRIRSBBTlNXRVI8L3RleHQ+PHBhdGggZD0iTTIwIDIwMVYyMDZIMjk4VjIwMSIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjY2RiNDhhIiBzdHJva2Utd2lkdGg9IjAuNzUiIC8+PHRleHQgeD0iMTU5LjAiIHk9IjIyMSIgZm9udC1mYW1pbHk9IlNwYWNlIE1vbm8sIHVpLW1vbm9zcGFjZSwgbW9ub3NwYWNlIiBmb250LXNpemU9IjkiIGZpbGw9IiM2YjU2MzgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI0MDAiIGxldHRlci1zcGFjaW5nPSIxLjYiPlRIRSBNT0RFTDwvdGV4dD48cGF0aCBkPSJNMzM2IDIwMVYyMDZINDg2VjIwMSIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjY2RiNDhhIiBzdHJva2Utd2lkdGg9IjAuNzUiIC8+PHRleHQgeD0iNDExLjAiIHk9IjIyMSIgZm9udC1mYW1pbHk9IlNwYWNlIE1vbm8sIHVpLW1vbm9zcGFjZSwgbW9ub3NwYWNlIiBmb250LXNpemU9IjkiIGZpbGw9IiM2YjU2MzgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI0MDAiIGxldHRlci1zcGFjaW5nPSIxLjYiPllPVVIgUiBTRVNTSU9OPC90ZXh0PjxwYXRoIGQ9Ik01MjQgMjAxVjIwNkg2NDRWMjAxIiBmaWxsPSJub25lIiBzdHJva2U9IiNjZGI0OGEiIHN0cm9rZS13aWR0aD0iMC43NSIgLz48dGV4dCB4PSI1ODQuMCIgeT0iMjIxIiBmb250LWZhbWlseT0iU3BhY2UgTW9ubywgdWktbW9ub3NwYWNlLCBtb25vc3BhY2UiIGZvbnQtc2l6ZT0iOSIgZmlsbD0iIzZiNTYzOCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjQwMCIgbGV0dGVyLXNwYWNpbmc9IjEuNiI+VEhFIFRPT0w8L3RleHQ+PC9zdmc+)

Fig. 1 · One turn of the ReAct loop, with securetools checks in the
middle

Pass the tools to
[`agent()`](https://ian-flores.github.io/orchestr/reference/Agent.html)
with `secure = TRUE` so the agent’s code runs in a securer session.

``` r

# Create security-scoped tools
calc <- tool_calculator()
reader <- tool_read_file(allowed_dirs = "/path/to/project/data")

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

With `secure = TRUE`, orchestr starts a `SecureSession` and converts
each `securer_tool` into an ellmer tool. The path checks, the
calculator’s function list, and the call limits all run in the parent
process.

## A supervisor with specialist workers

Another option is to split the tools across several agents, so each one
has only what it needs. A supervisor agent reads the request and hands
it to the right worker. The supervisor has no tools of its own.

Each worker gets its own `SecureSession`, with its own allowed folders,
allowed domains, and call limits. A file worker that gets hijacked still
can’t make web requests, because it was never given that tool. The
supervisor only sees the workers’ answers, not the raw tool output. You
can also set limits per role, for example a generous call limit for the
data worker and a tight one for the worker that writes files.

![](data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIGFyaWEtbGFiZWw9IkEgc3VwZXJ2aXNvciByb3V0ZXMgYSByZXF1ZXN0IHRvIGEgZmlsZSB3b3JrZXIsIGEgZGF0YSB3b3JrZXIsIG9yIGEgcmVzZWFyY2ggd29ya2VyIiB2aWV3Ym94PSIwIDAgOTAwIDI2MiIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZGVmcz48bWFya2VyIGlkPSJzdi1hcnJvdyIgdmlld2JveD0iMCAwIDEwIDEwIiByZWZ4PSI5IiByZWZ5PSI1IiBtYXJrZXJ3aWR0aD0iNyIgbWFya2VyaGVpZ2h0PSI3IiBvcmllbnQ9ImF1dG8tc3RhcnQtcmV2ZXJzZSI+PHBhdGggZD0iTTEgMUw5IDVMMSA5IiBmaWxsPSJub25lIiBzdHJva2U9IiMyYjFmMTIiIHN0cm9rZS13aWR0aD0iMSIgLz48L21hcmtlcj48cGF0dGVybiBpZD0ic3YtaGF0Y2giIHdpZHRoPSI2IiBoZWlnaHQ9IjYiIHBhdHRlcm51bml0cz0idXNlclNwYWNlT25Vc2UiIHBhdHRlcm50cmFuc2Zvcm09InJvdGF0ZSg0NSkiPjxsaW5lIHgxPSIwIiB5MT0iMCIgeDI9IjAiIHkyPSI2IiBzdHJva2U9IiNiZjVhMzYiIHN0cm9rZS13aWR0aD0iMC42IiBvcGFjaXR5PSIwLjU1Ij48L2xpbmU+PC9wYXR0ZXJuPjwvZGVmcz48dGV4dCB4PSI0NTAiIHk9IjIyIiBmb250LWZhbWlseT0iU3BhY2UgTW9ubywgdWktbW9ub3NwYWNlLCBtb25vc3BhY2UiIGZvbnQtc2l6ZT0iOS41IiBmaWxsPSIjNmI1NjM4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNDAwIiBsZXR0ZXItc3BhY2luZz0iMSI+4oCcUkVBRCBTQUxFUy5DU1YsIENPTVBVVEUgTUVBTiBSRVZFTlVF4oCdPC90ZXh0PjxwYXRoIGQ9Ik00NTAgMzBWNDgiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzJiMWYxMiIgc3Ryb2tlLXdpZHRoPSIwLjc1IiBtYXJrZXItZW5kPSJ1cmwoI3N2LWFycm93KSIgLz48cmVjdCB4PSIzNDAiIHk9IjUwIiB3aWR0aD0iMjIwIiBoZWlnaHQ9IjU2IiBmaWxsPSJub25lIiBzdHJva2U9IiMyYjFmMTIiIHN0cm9rZS13aWR0aD0iMC43NSIgLz48dGV4dCB4PSI0NTAuMCIgeT0iNjguMCIgZm9udC1mYW1pbHk9IlNwYWNlIE1vbm8sIHVpLW1vbm9zcGFjZSwgbW9ub3NwYWNlIiBmb250LXNpemU9IjEwLjUiIGZpbGw9IiMyYjFmMTIiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI3MDAiIGxldHRlci1zcGFjaW5nPSIxLjIiPlNVUEVSVklTT1I8L3RleHQ+PHRleHQgeD0iNDUwLjAiIHk9IjgyLjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSI5IiBmaWxsPSIjNmI1NjM4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNDAwIiBsZXR0ZXItc3BhY2luZz0iMC40Ij5yb3V0ZXMgdGhlIHJlcXVlc3Q8L3RleHQ+PHRleHQgeD0iNDUwLjAiIHk9Ijk1LjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSI5IiBmaWxsPSIjNmI1NjM4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNDAwIiBsZXR0ZXItc3BhY2luZz0iMC40Ij5oYXMgbm8gdG9vbHMgb2YgaXRzIG93bjwvdGV4dD48cGF0aCBkPSJNNDUwIDEwNlYxMjgiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzJiMWYxMiIgc3Ryb2tlLXdpZHRoPSIwLjc1IiAvPjxwYXRoIGQ9Ik0xNzAgMTI4SDczMCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMmIxZjEyIiBzdHJva2Utd2lkdGg9IjAuNzUiIC8+PHBhdGggZD0iTTE3MCAxMjhWMTU4IiBmaWxsPSJub25lIiBzdHJva2U9IiMyYjFmMTIiIHN0cm9rZS13aWR0aD0iMC43NSIgbWFya2VyLWVuZD0idXJsKCNzdi1hcnJvdykiIC8+PHJlY3QgeD0iNTIiIHk9IjE1MiIgd2lkdGg9IjIzNiIgaGVpZ2h0PSI5NiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjY2RiNDhhIiBzdHJva2Utd2lkdGg9IjAuNzUiIHN0cm9rZS1kYXNoYXJyYXk9IjMgMyIgLz48cmVjdCB4PSI2MCIgeT0iMTYwIiB3aWR0aD0iMjIwIiBoZWlnaHQ9IjY2IiBmaWxsPSJub25lIiBzdHJva2U9IiMyYjFmMTIiIHN0cm9rZS13aWR0aD0iMC43NSIgLz48dGV4dCB4PSIxNzAuMCIgeT0iMTgzLjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSIxMC41IiBmaWxsPSIjMmIxZjEyIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNzAwIiBsZXR0ZXItc3BhY2luZz0iMS4yIj5GSUxFIFdPUktFUjwvdGV4dD48dGV4dCB4PSIxNzAuMCIgeT0iMTk3LjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSI5IiBmaWxsPSIjNmI1NjM4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNDAwIiBsZXR0ZXItc3BhY2luZz0iMC40Ij5yZWFkX2ZpbGU8L3RleHQ+PHRleHQgeD0iMTcwLjAiIHk9IjIxMC4wIiBmb250LWZhbWlseT0iU3BhY2UgTW9ubywgdWktbW9ub3NwYWNlLCBtb25vc3BhY2UiIGZvbnQtc2l6ZT0iOSIgZmlsbD0iIzZiNTYzOCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjQwMCIgbGV0dGVyLXNwYWNpbmc9IjAuNCI+d3JpdGVfZmlsZTwvdGV4dD48dGV4dCB4PSIxNzAiIHk9IjI0MCIgZm9udC1mYW1pbHk9IlNwYWNlIE1vbm8sIHVpLW1vbm9zcGFjZSwgbW9ub3NwYWNlIiBmb250LXNpemU9IjgiIGZpbGw9IiM2YjU2MzgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI0MDAiIGxldHRlci1zcGFjaW5nPSIxLjQiPk9XTiBTRUNVUkVTRVNTSU9OPC90ZXh0PjxwYXRoIGQ9Ik00NTAgMTI4VjE1OCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMmIxZjEyIiBzdHJva2Utd2lkdGg9IjAuNzUiIG1hcmtlci1lbmQ9InVybCgjc3YtYXJyb3cpIiAvPjxyZWN0IHg9IjMzMiIgeT0iMTUyIiB3aWR0aD0iMjM2IiBoZWlnaHQ9Ijk2IiBmaWxsPSJub25lIiBzdHJva2U9IiNjZGI0OGEiIHN0cm9rZS13aWR0aD0iMC43NSIgc3Ryb2tlLWRhc2hhcnJheT0iMyAzIiAvPjxyZWN0IHg9IjM0MCIgeT0iMTYwIiB3aWR0aD0iMjIwIiBoZWlnaHQ9IjY2IiBmaWxsPSJub25lIiBzdHJva2U9IiMyYjFmMTIiIHN0cm9rZS13aWR0aD0iMC43NSIgLz48dGV4dCB4PSI0NTAuMCIgeT0iMTgzLjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSIxMC41IiBmaWxsPSIjMmIxZjEyIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNzAwIiBsZXR0ZXItc3BhY2luZz0iMS4yIj5EQVRBIFdPUktFUjwvdGV4dD48dGV4dCB4PSI0NTAuMCIgeT0iMTk3LjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSI5IiBmaWxsPSIjNmI1NjM4IiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNDAwIiBsZXR0ZXItc3BhY2luZz0iMC40Ij5jYWxjdWxhdG9yPC90ZXh0Pjx0ZXh0IHg9IjQ1MC4wIiB5PSIyMTAuMCIgZm9udC1mYW1pbHk9IlNwYWNlIE1vbm8sIHVpLW1vbm9zcGFjZSwgbW9ub3NwYWNlIiBmb250LXNpemU9IjkiIGZpbGw9IiM2YjU2MzgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI0MDAiIGxldHRlci1zcGFjaW5nPSIwLjQiPmRhdGFfcHJvZmlsZTwvdGV4dD48dGV4dCB4PSI0NTAiIHk9IjI0MCIgZm9udC1mYW1pbHk9IlNwYWNlIE1vbm8sIHVpLW1vbm9zcGFjZSwgbW9ub3NwYWNlIiBmb250LXNpemU9IjgiIGZpbGw9IiM2YjU2MzgiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSI0MDAiIGxldHRlci1zcGFjaW5nPSIxLjQiPk9XTiBTRUNVUkVTRVNTSU9OPC90ZXh0PjxwYXRoIGQ9Ik03MzAgMTI4VjE1OCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMmIxZjEyIiBzdHJva2Utd2lkdGg9IjAuNzUiIG1hcmtlci1lbmQ9InVybCgjc3YtYXJyb3cpIiAvPjxyZWN0IHg9IjYxMiIgeT0iMTUyIiB3aWR0aD0iMjM2IiBoZWlnaHQ9Ijk2IiBmaWxsPSJub25lIiBzdHJva2U9IiNjZGI0OGEiIHN0cm9rZS13aWR0aD0iMC43NSIgc3Ryb2tlLWRhc2hhcnJheT0iMyAzIiAvPjxyZWN0IHg9IjYyMCIgeT0iMTYwIiB3aWR0aD0iMjIwIiBoZWlnaHQ9IjY2IiBmaWxsPSJub25lIiBzdHJva2U9IiMyYjFmMTIiIHN0cm9rZS13aWR0aD0iMC43NSIgLz48dGV4dCB4PSI3MzAuMCIgeT0iMTkwLjAiIGZvbnQtZmFtaWx5PSJTcGFjZSBNb25vLCB1aS1tb25vc3BhY2UsIG1vbm9zcGFjZSIgZm9udC1zaXplPSIxMC41IiBmaWxsPSIjMmIxZjEyIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iNzAwIiBsZXR0ZXItc3BhY2luZz0iMS4yIj5SRVNFQVJDSCBXT1JLRVI8L3RleHQ+PHRleHQgeD0iNzMwLjAiIHk9IjIwNC4wIiBmb250LWZhbWlseT0iU3BhY2UgTW9ubywgdWktbW9ub3NwYWNlLCBtb25vc3BhY2UiIGZvbnQtc2l6ZT0iOSIgZmlsbD0iIzZiNTYzOCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjQwMCIgbGV0dGVyLXNwYWNpbmc9IjAuNCI+ZmV0Y2hfdXJsPC90ZXh0Pjx0ZXh0IHg9IjczMCIgeT0iMjQwIiBmb250LWZhbWlseT0iU3BhY2UgTW9ubywgdWktbW9ub3NwYWNlLCBtb25vc3BhY2UiIGZvbnQtc2l6ZT0iOCIgZmlsbD0iIzZiNTYzOCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9IjQwMCIgbGV0dGVyLXNwYWNpbmc9IjEuNCI+T1dOIFNFQ1VSRVNFU1NJT048L3RleHQ+PC9zdmc+)

Fig. 2 · Each worker gets its own session, rate limits, and allow-lists

Here is a supervisor with a data worker and a file worker:

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
    tool_calculator(),
    tool_data_profile(max_rows = 50000)
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
    tool_read_file(allowed_dirs = "/path/to/project/data"),
    tool_write_file(allowed_dirs = "/path/to/project/output")
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

The supervisor routes with a `route` tool that
[`supervisor_graph()`](https://ian-flores.github.io/orchestr/reference/graph_supervisor.html)
adds for it.

## Call limits in agent loops

In an agent loop, the model decides how many times to call a tool. An
agent that misreads a task might call the calculator 500 times to
“check” its answer. A research agent might keep following links and
hammer an API. Each of those calls costs tokens and time.

securetools has two kinds of limit:

- `max_calls` caps the total number of calls to a tool. Once it’s
  reached, every later call fails. This is the one that stops a runaway
  loop.
- `max_calls_per_minute` (only on
  [`tool_fetch_url()`](https://ian-flores.github.io/securetools/reference/tool_fetch_url.md))
  caps how often the tool can be called. You might allow 1000 calls in
  total but only 10 a minute, so an external service isn’t flooded.

When a limit is reached, the tool raises an error. ellmer passes the
error back to the model as the tool’s result, so the agent can stop or,
for example, summarize what it already has instead of fetching more.

``` r

# Cap the calculator at 50 calls per agent session
calc <- tool_calculator(max_calls = 50)

# URL fetch with both lifetime and per-minute limits
fetcher <- tool_fetch_url(
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

[`tool_fetch_url()`](https://ian-flores.github.io/securetools/reference/tool_fetch_url.md)
can’t fetch HTTPS URLs at the moment (see
[`vignette("securetools")`](https://ian-flores.github.io/securetools/articles/securetools.md)),
so this agent would get an error back from `https://api.github.com`
until that is fixed.

## Custom tools next to securetools

Most agents need something securetools doesn’t have. You can put your
own
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
definitions in the same agent as the built-in ones.

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
    tool_calculator(),
    tool_read_file(allowed_dirs = "/path/to/data"),
    timestamp_tool
  ),
  secure = TRUE
)

graph <- react_graph(assistant)

result <- graph$invoke(list(messages = list(
  "What time is it? Also, what is 2^10?"
)))
```

A custom tool’s `fn` runs in the parent process, like the securetools
ones. The difference is that it only has the checks you write into it.

## Next steps

- [`vignette("securetools")`](https://ian-flores.github.io/securetools/articles/securetools.md):
  the tools and what each one checks
- [`vignette("quickstart", package = "orchestr")`](https://ian-flores.github.io/orchestr/articles/quickstart.html):
  agent and graph basics
- [`vignette("ellmer-integration", package = "securer")`](https://ian-flores.github.io/securer/articles/ellmer-integration.html):
  connecting securer to ellmer directly
