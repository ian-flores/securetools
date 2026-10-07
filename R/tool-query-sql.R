# --- SQL query tool ---

#' Create a SQL query tool
#'
#' Returns a [securer::securer_tool()] that runs a SELECT on one table.
#' The caller names the table, the columns, and an optional filter, and the
#' tool writes the SQL. It never accepts SQL text, so there is nothing to
#' inject into.
#'
#' @param conn A DBI connection.
#' @param allowed_tables Character vector of tables the tool can query.
#' @param max_rows The most rows a query returns. Default 1000.
#' @param max_calls The most times the tool can be called. `NULL` means no
#'   limit.
#'
#' @details
#' The table must be one of `allowed_tables`. Column names aren't checked
#' against a list, but they must be plain identifiers (letters, digits, and
#' underscores, not starting with a digit). Table and column names are also
#' quoted with [DBI::dbQuoteIdentifier()].
#'
#' The filter is a single `column = value` condition. The value is passed
#' as a query parameter and is never pasted into the SQL. Every query ends
#' with `LIMIT max_rows`.
#'
#' @return A `securer_tool` object.
#'
#' @family tool factories
#' @seealso \code{\link[securer]{securer_tool}}
#'
#' @examples
#' \donttest{
#' tool <- tool_query_sql(
#'   conn = DBI::dbConnect(RSQLite::SQLite(), ":memory:"),
#'   allowed_tables = c("customers", "orders"),
#'   max_rows = 500
#' )
#' }
#' @export
tool_query_sql <- function(conn, allowed_tables, max_rows = 1000,
                           max_calls = NULL) {
  rlang::check_installed("DBI", reason = "to use tool_query_sql()")

  # Factory argument validation
  if (!inherits(conn, "DBIConnection")) {
    cli_abort("{.arg conn} must be a DBI connection object.")
  }

  if (!is.character(allowed_tables) || length(allowed_tables) == 0L) {
    cli_abort("{.arg allowed_tables} must be a non-empty character vector.")
  }
  if (!is.numeric(max_rows) || length(max_rows) != 1L || max_rows < 1L) {
    cli_abort("{.arg max_rows} must be a positive number.")
  }
  if (!is.null(max_calls) && (!is.numeric(max_calls) || length(max_calls) != 1L || max_calls < 1L)) {
    cli_abort("{.arg max_calls} must be NULL or a positive number.")
  }

  limiter <- new_rate_limiter(max_calls)

  securer::securer_tool(
    name = "query_sql",
    description = "Query a database table. Specify table, columns, and optional filter. No raw SQL allowed.",
    fn = function(table, columns = "*", filter_column = "", filter_value = "") {
      .do_query <- function() {
        check_rate_limit(limiter)

        # Validate table name against allow-list
        validate_sql_identifier(table, allowed = allowed_tables, what = "table")

        # Quote table identifier for defense in depth
        table_q <- DBI::dbQuoteIdentifier(conn, table)

        # Parse and validate columns
        if (!identical(columns, "*")) {
          col_names <- trimws(strsplit(columns, ",")[[1]])
          for (col in col_names) {
            validate_sql_identifier(col, what = "column")
          }
          cols_sql <- paste(vapply(col_names, function(c) as.character(DBI::dbQuoteIdentifier(conn, c)), character(1)), collapse = ", ")
        } else {
          cols_sql <- "*"
        }

        # Build query
        has_filter <- nzchar(filter_column) && nzchar(filter_value)

        if (has_filter) {
          validate_sql_identifier(filter_column, what = "column")
          filter_q <- DBI::dbQuoteIdentifier(conn, filter_column)
          sql <- paste0("SELECT ", cols_sql, " FROM ", table_q,
                        " WHERE ", filter_q, " = ?",
                        " LIMIT ", max_rows)
          params <- list(filter_value)
        } else {
          sql <- paste0("SELECT ", cols_sql, " FROM ", table_q,
                        " LIMIT ", max_rows)
          params <- NULL
        }

        # Execute parameterized query
        if (!is.null(params)) {
          DBI::dbGetQuery(conn, sql, params = params)
        } else {
          DBI::dbGetQuery(conn, sql)
        }
      }

      if (.trace_active()) {
        .with_span("tool.query_sql", {
          result <- .do_query()
          .span_event("tool.result", list(tool = "query_sql"))
          result
        })
      } else {
        .do_query()
      }
    },
    args = list(
      table = "character",
      columns = "character",
      filter_column = "character",
      filter_value = "character"
    )
  )
}

