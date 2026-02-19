# --- SQL query tool ---

#' Create a SQL query tool
#'
#' Returns a [securer::securer_tool()] that queries database tables
#' via a structured interface with parameterized queries. No raw SQL
#' is accepted -- this makes SQL injection structurally impossible.
#'
#' @param conn A DBI connection object.
#' @param allowed_tables Character vector of table names the tool can query.
#' @param max_rows Maximum rows returned. Default 1000.
#' @param read_only If TRUE (default), only SELECT queries are allowed.
#' @param max_calls Maximum invocations. `NULL` means unlimited.
#' @return A `securer_tool` object.
#' @export
query_sql_tool <- function(conn, allowed_tables, max_rows = 1000,
                           read_only = TRUE, max_calls = NULL) {
  rlang::check_installed("DBI", reason = "to use query_sql_tool()")
  limiter <- new_rate_limiter(max_calls)

  securer::securer_tool(
    name = "query_sql",
    description = "Query a database table. Specify table, columns, and optional filter. No raw SQL allowed.",
    fn = function(table, columns = "*", filter_column = "", filter_value = "") {
      check_rate_limit(limiter)

      # Validate table name against allow-list
      validate_sql_identifier(table, allowed = allowed_tables, what = "table")

      # Parse and validate columns
      if (!identical(columns, "*")) {
        col_names <- trimws(strsplit(columns, ",")[[1]])
        for (col in col_names) {
          validate_sql_identifier(col, what = "column")
        }
        cols_sql <- paste(col_names, collapse = ", ")
      } else {
        cols_sql <- "*"
      }

      # Build query
      has_filter <- nzchar(filter_column) && nzchar(filter_value)

      if (has_filter) {
        validate_sql_identifier(filter_column, what = "column")
        sql <- paste0("SELECT ", cols_sql, " FROM ", table,
                      " WHERE ", filter_column, " = ?",
                      " LIMIT ", max_rows)
        params <- list(filter_value)
      } else {
        sql <- paste0("SELECT ", cols_sql, " FROM ", table,
                      " LIMIT ", max_rows)
        params <- NULL
      }

      # Execute parameterized query
      if (!is.null(params)) {
        DBI::dbGetQuery(conn, sql, params = params)
      } else {
        DBI::dbGetQuery(conn, sql)
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
