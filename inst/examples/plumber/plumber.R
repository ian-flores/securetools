# Governed Agent Plumber API
#
# REST API demonstrating the securer + secureguard + securetools chain:
# guarded chat, standalone guardrail checks, and sandboxed code execution
# with security-hardened tools.
#
# Endpoints:
#   POST /chat       -- Governed agent endpoint with input/output guardrails
#   POST /guardrail  -- Run a guardrail check on text
#   POST /execute    -- Execute R code in a sandboxed pooled session with
#                       securetools tools (code guardrails enforced)
#   GET  /health     -- Package healthcheck
#
# Observability note: this example intentionally has no bespoke tracing.
# In production, use ellmer's native OpenTelemetry support to trace the
# LLM side of the agent.

library(securer)
library(securetools)
library(secureguard)

# --- Shared state -----------------------------------------------------------

# Guardrail pipeline
guardrail_pipeline <- secure_pipeline(
  input_guardrails = list(
    guard_prompt_injection(),
    guard_input_pii()
  ),
  code_guardrails = list(
    guard_code_analysis(),
    guard_code_complexity(max_ast_depth = 20)
  ),
  output_guardrails = list(
    guard_output_pii(action = "redact"),
    guard_output_secrets(action = "redact")
  )
)

# Simple counters (in-memory for demo)
stats_store <- new.env(parent = emptyenv())
stats_store$guardrail_checks <- 0L
stats_store$guardrail_passes <- 0L
stats_store$guardrail_blocks <- 0L

# Session pool for sandboxed execution, pre-loaded with hardened tools.
# The workspace confines every file the sandbox can touch.
workspace <- file.path(tempdir(), "agent-workspace")
dir.create(workspace, showWarnings = FALSE, recursive = TRUE)

session_pool <- SecureSessionPool$new(
  size = 2,
  tools = list(
    tool_calculator(),
    tool_data_profile(),
    tool_read_file(allowed_dirs = workspace),
    tool_write_file(allowed_dirs = workspace, overwrite = TRUE)
  ),
  sandbox = FALSE # set TRUE in production (Seatbelt / bubblewrap)
)

# --- Helpers -----------------------------------------------------------------

count_check <- function(pass) {
  stats_store$guardrail_checks <- stats_store$guardrail_checks + 1L
  if (isTRUE(pass)) {
    stats_store$guardrail_passes <- stats_store$guardrail_passes + 1L
  } else {
    stats_store$guardrail_blocks <- stats_store$guardrail_blocks + 1L
  }
  invisible(pass)
}

# Mock LLM response (no external API required). Swap for
# ellmer::chat_anthropic() / ellmer::chat_openai() in production.
mock_llm_response <- function(message) {
  responses <- list(
    default = "I can help you with R programming. Could you be more specific?",
    math = "I can calculate that for you using R's built-in math functions.",
    data = "For data analysis, I recommend using dplyr and ggplot2.",
    help = "I'm a governed AI assistant for R programming questions."
  )

  msg_lower <- tolower(message)
  if (grepl("calculat|math|\\d+", msg_lower)) {
    responses$math
  } else if (grepl("data|analysis|csv", msg_lower)) {
    responses$data
  } else if (grepl("help|who|what are", msg_lower)) {
    responses$help
  } else {
    responses$default
  }
}

# --- Endpoints ---------------------------------------------------------------

#* Health check -- loads all packages and reports status
#* @get /health
#* @serializer unboxedJSON
function() {
  packages <- c("securer", "securetools", "secureguard")
  status <- vapply(packages, function(pkg) {
    tryCatch({
      requireNamespace(pkg, quietly = TRUE)
      "ok"
    }, error = function(e) "error")
  }, character(1))

  list(
    status = if (all(status == "ok")) "healthy" else "degraded",
    packages = as.list(status),
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    pool_size = session_pool$size()
  )
}

#* Governed agent chat endpoint
#* @post /chat
#* @param message:character The user message
#* @serializer unboxedJSON
function(req, res, message = "") {
  if (!nzchar(message)) {
    res$status <- 400L
    return(list(error = "message parameter is required"))
  }

  # Input guardrail check
  input_check <- guardrail_pipeline$check_input(message)
  count_check(input_check$pass)

  if (!input_check$pass) {
    return(list(
      blocked = TRUE,
      reasons = input_check$reasons
    ))
  }

  # LLM call (mocked)
  response <- mock_llm_response(message)

  # Output guardrail check (redacts PII/secrets rather than blocking)
  output_check <- guardrail_pipeline$check_output(response)
  count_check(output_check$pass)

  list(
    response = output_check$result,
    blocked = FALSE,
    guardrails = list(
      input_pass = input_check$pass,
      output_pass = output_check$pass,
      warnings = c(input_check$warnings, output_check$warnings)
    )
  )
}

#* Execute R code in a sandboxed session with securetools tools
#* @post /execute
#* @param code:character R code to execute
#* @serializer unboxedJSON
function(req, res, code = "") {
  if (!nzchar(code)) {
    res$status <- 400L
    return(list(error = "code parameter is required"))
  }

  # Code guardrail check before the sandbox ever sees the code
  code_check <- guardrail_pipeline$check_code(code)
  count_check(code_check$pass)

  if (!code_check$pass) {
    return(list(
      blocked = TRUE,
      reasons = code_check$reasons
    ))
  }

  result <- tryCatch(
    session_pool$execute(code),
    error = function(e) NULL
  )

  if (is.null(result)) {
    res$status <- 422L
    return(list(error = "execution failed", blocked = FALSE))
  }

  # Output guardrail on anything leaving the sandbox
  output_check <- guardrail_pipeline$check_output(
    paste(as.character(result), collapse = "\n")
  )
  count_check(output_check$pass)

  list(
    result = output_check$result,
    blocked = FALSE,
    guardrails = list(
      code_pass = code_check$pass,
      output_pass = output_check$pass
    )
  )
}

#* Run guardrail check on text
#* @post /guardrail
#* @param text:character Text to check
#* @param type:character Guardrail type (input, code, output)
#* @serializer unboxedJSON
function(req, res, text = "", type = "input") {
  if (!nzchar(text)) {
    res$status <- 400L
    return(list(error = "text parameter is required"))
  }

  result <- switch(type,
    "input" = guardrail_pipeline$check_input(text),
    "code" = guardrail_pipeline$check_code(text),
    "output" = guardrail_pipeline$check_output(text),
    {
      res$status <- 400L
      return(list(error = "type must be one of: input, code, output"))
    }
  )
  count_check(result$pass)

  list(
    pass = result$pass,
    type = type,
    warnings = result$warnings,
    reasons = if (!result$pass) result$reasons else list()
  )
}
