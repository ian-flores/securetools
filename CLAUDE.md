# securetools -- Development Guide

## What This Is

An R package providing pre-built security-hardened tool definitions for use with securer. Each tool factory returns a `securer::securer_tool()` object with built-in security constraints.

## Architecture

Tool factories return `securer_tool()` objects. The `fn` closure captures config (allow-lists, limits, rate limiter). The fn runs in the parent process.

Key files:
- `R/utils-validate.R` -- Path validation, size limits, SQL identifier checks
- `R/utils-rate-limit.R` -- Per-tool invocation rate limiter
- `R/tool-*.R` -- One file per tool factory

## Development Commands

```bash
Rscript -e "devtools::test('.')"
Rscript -e "devtools::check('.')"
Rscript -e "devtools::document('.')"
```

## Test Patterns

- Use `withr::local_tempdir()` for temp directories
- Use `skip_if_not_installed()` for optional dependencies
- Use `skip_if_no_session()` for tests requiring SecureSession
- Test security rejections (path traversal, injection) as well as happy paths
