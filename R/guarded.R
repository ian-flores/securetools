#' Wrap a securer_tool with input and output guardrails
#'
#' Composes a tool from [securer::securer_tool()] with guardrails from
#' \pkg{secureguard}. The returned object is itself a
#' [securer::securer_tool()] (same schema, same IPC contract) whose
#' closure runs each invocation through the supplied input guardrails,
#' executes the underlying tool, then runs the result through the output
#' guardrails.
#'
#' Guardrail failures are translated into errors raised from the tool
#' closure; inside a securer session these surface as tool-call errors
#' and are returned to the LLM via ellmer's `ContentToolResult(error =)`
#' shape.
#'
#' Guardrails are applied lazily: if \pkg{secureguard} is not installed,
#' calling [guarded_tool()] errors with a clear installation hint rather
#' than silently skipping enforcement.
#'
#' @param tool A `securer_tool` object (typically from one of the
#'   `tool_*()` factories in this package, but any `securer_tool` works).
#' @param input_guards A list of `secureguard` input guardrails (type
#'   `"input"` or `"code"`). Each receives the stringified tool args and
#'   must pass for the call to proceed.
#' @param output_guards A list of `secureguard` output guardrails (type
#'   `"output"`). Each receives the tool's return value (coerced to text
#'   via `secureguard::output_to_text`) and must pass for the result to
#'   be returned.
#' @return A new `securer_tool` object with guardrails applied.
#' @export
#' @examples
#' \dontrun{
#'   calc <- tool_calculator()
#'   injection <- secureguard::guard_prompt_injection()
#'   secrets <- secureguard::guard_output_secrets(action = "block")
#'   guarded <- guarded_tool(
#'     calc,
#'     input_guards = list(injection),
#'     output_guards = list(secrets)
#'   )
#' }
guarded_tool <- function(tool,
                         input_guards = list(),
                         output_guards = list()) {
  if (!requireNamespace("secureguard", quietly = TRUE)) {
    cli_abort(
      "{.pkg secureguard} is required for {.fn guarded_tool}. Install it
       from GitHub with {.code pak::pak('ian-flores/secureguard')}."
    )
  }
  if (!requireNamespace("securer", quietly = TRUE)) {
    cli_abort(
      "{.pkg securer} is required for {.fn guarded_tool}. Install it
       from GitHub with {.code pak::pak('ian-flores/securer')}."
    )
  }
  if (!inherits(tool, "securer_tool_class") &&
      !inherits(tool, "securer::securer_tool_class") &&
      !S4_is_securer_tool(tool)) {
    cli_abort(
      "{.arg tool} must be a {.cls securer_tool} object (from
       {.pkg securer} or one of the {.fn tool_*} factories in this
       package)."
    )
  }
  if (!is.list(input_guards)) cli_abort("{.arg input_guards} must be a list.")
  if (!is.list(output_guards)) cli_abort("{.arg output_guards} must be a list.")

  inner <- tool@fn
  args_schema <- tool@args
  name <- tool@name

  guarded_fn <- function(...) {
    call_args <- list(...)

    # Input stage: stringify args and run every input guardrail.
    if (length(input_guards) > 0L) {
      payload <- .guarded_args_to_text(call_args)
      for (g in input_guards) {
        res <- secureguard::run_guardrail(g, payload)
        if (!isTRUE(res@pass)) {
          cli_abort(
            "guarded_tool[{.val {name}}] blocked by input guardrail
             {.val {g@name}}: {res@reason}"
          )
        }
      }
    }

    result <- do.call(inner, call_args)

    # Output stage: coerce result to text and run every output guardrail.
    if (length(output_guards) > 0L) {
      text <- secureguard::output_to_text(result)
      for (g in output_guards) {
        res <- secureguard::run_guardrail(g, text)
        if (!isTRUE(res@pass)) {
          cli_abort(
            "guarded_tool[{.val {name}}] blocked by output guardrail
             {.val {g@name}}: {res@reason}"
          )
        }
      }
    }

    result
  }

  securer::securer_tool(
    name = name,
    fn   = guarded_fn,
    args = args_schema
  )
}

#' Pipe-friendly alias for [guarded_tool()]
#'
#' Lets you write
#' `tool_calculator() |> with_guards(input_guards = list(...))`.
#'
#' @param tool Same as [guarded_tool()].
#' @param ... Passed straight through to [guarded_tool()].
#' @return A new `securer_tool` object.
#' @export
with_guards <- function(tool, ...) {
  guarded_tool(tool, ...)
}

# --- internals ---

.guarded_args_to_text <- function(args) {
  if (length(args) == 0L) return("")
  parts <- mapply(
    function(name, value) {
      key <- if (is.null(name) || !nzchar(name)) "" else paste0(name, "=")
      paste0(key, .guarded_value_as_text(value))
    },
    names(args) %||% rep("", length(args)),
    args,
    USE.NAMES = FALSE,
    SIMPLIFY = TRUE
  )
  paste(parts, collapse = "\n")
}

.guarded_value_as_text <- function(x) {
  if (is.character(x) && length(x) == 1L) return(x)
  tryCatch(
    paste(format(x), collapse = " "),
    error = function(e) paste(deparse(x, nlines = 5L), collapse = " ")
  )
}

S4_is_securer_tool <- function(x) {
  # securer_tool is an S4 object; fall back to class-name check so we
  # don't hard-import methods. Guards against type drift across releases.
  classes <- class(x)
  any(grepl("securer_tool", classes))
}

`%||%` <- function(x, y) if (is.null(x)) y else x
