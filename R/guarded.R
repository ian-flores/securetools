#' Add secureguard checks to a tool
#'
#' Wraps a [securer::securer_tool()] so that every call runs
#' \pkg{secureguard} guardrails on the arguments before the tool runs, and
#' on the result afterwards. The result is still a
#' [securer::securer_tool()] with the same name, description, and
#' arguments, so you use it the same way as the original.
#'
#' If a guardrail fails, the tool raises an error. Inside a securer session
#' that becomes a tool-call error, which ellmer passes back to the model
#' as an error result.
#'
#' \pkg{secureguard} is only needed when you call `guarded_tool()`. If it
#' isn't installed, `guarded_tool()` stops with an error that says how to
#' install it. It never returns a tool without the checks.
#'
#' @param tool A `securer_tool`, usually from one of the `tool_*()`
#'   functions in this package. Any `securer_tool` works.
#' @param input_guards A list of secureguard guardrails of type `"input"`
#'   or `"code"`. The tool's arguments are turned into text and each
#'   guardrail must pass before the tool runs.
#' @param output_guards A list of secureguard guardrails of type
#'   `"output"`. The tool's result is turned into text with
#'   `secureguard::output_to_text()`, and each guardrail must pass before
#'   the result is returned.
#' @return A new `securer_tool` with the checks added.
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
  description <- tool@description

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
    name        = name,
    description = description,
    fn          = guarded_fn,
    args        = args_schema
  )
}

#' Add secureguard checks to a tool, in a pipe
#'
#' The same as [guarded_tool()], named so it reads well in a pipe:
#' `tool_calculator() |> with_guards(input_guards = list(...))`.
#'
#' @param tool Same as [guarded_tool()].
#' @param ... Passed on to [guarded_tool()].
#' @return A new `securer_tool` with the checks added.
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
