# Internal tracing helpers -- not exported
# otel (OpenTelemetry) is a soft dependency (Suggests only)

is_otel_tracing <- function() {
  requireNamespace("otel", quietly = TRUE) && otel::is_tracing_enabled()
}

.trace_active <- function() {
  is_otel_tracing()
}

# Run `expr` inside an active otel span named `name`. The span ends when
# this function returns. Falls back to plain evaluation when tracing is
# off or otel is not installed.
.with_span <- function(name, expr) {
  if (!.trace_active()) {
    return(expr)
  }
  otel::start_local_active_span(name, tracer = otel_tracer_name)
  expr
}

.span_event <- function(name, data = list()) {
  if (.trace_active()) {
    span <- otel::get_active_span()
    if (!is.null(span)) {
      span$add_event(name, attributes = otel::as_attributes(data))
    }
  }
  invisible(NULL)
}
