# securetools Examples

End-to-end examples demonstrating the governed AI agent chain for R:
[securer](https://github.com/ian-flores/securer) (sandboxed execution) +
[secureguard](https://github.com/ian-flores/secureguard) (guardrails) +
securetools (hardened tool definitions).

Ported from the archived `secure-r-dev-ecosystem` repository and pruned to
the surviving package lineup. The old Prometheus/Grafana/Jaeger tracing
demos were dropped; for observability, use
[ellmer](https://ellmer.tidyverse.org/)'s native OpenTelemetry support.

## Contents

### [Plumber API](plumber/)

REST API exposing a governed agent:

- `POST /chat` -- Chat endpoint with input/output guardrail checks
  (mocked LLM; swap in `ellmer::chat_anthropic()` for production)
- `POST /execute` -- Sandboxed code execution against a pre-warmed
  `SecureSessionPool` loaded with securetools tools (calculator, data
  profile, path-scoped file read/write); code guardrails run before the
  sandbox, output guardrails after
- `POST /guardrail` -- Run a guardrail check on arbitrary text
- `GET /health` -- Package healthcheck

Run locally (requires `plumber`, `securer`, `secureguard`, `securetools`):

```r
setwd(system.file("examples", "plumber", package = "securetools"))
source("entrypoint.R")
```

Or with Docker:

```bash
cd plumber && docker build -t securetools-plumber . && \
  docker run --rm -p 8000:8000 securetools-plumber
```

Smoke tests (with the API running):

```bash
Rscript plumber/tests/test-api.R
```

## Requirements

The examples run without external API keys; where LLM calls would normally
be needed, mock responses are returned.

```r
pak::pak(c("ian-flores/securer", "ian-flores/secureguard",
           "ian-flores/securetools", "plumber"))
```
