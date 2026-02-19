# Internal validation helpers for securetools
# All functions use cli_abort() for errors.

#' Validate that a path is within allowed directories
#'
#' Resolves symlinks and checks the real path is within at least one allowed dir.
#'
#' @param path Character(1). Path to validate.
#' @param allowed_dirs Character vector of allowed parent directories.
#' @param must_exist Logical(1). If TRUE (default), the path must exist.
#'   If FALSE, the parent directory must exist and be within allowed_dirs.
#' @return The resolved path (invisibly).
#' @noRd
validate_path <- function(path, allowed_dirs, must_exist = TRUE) {
  # NOTE: When must_exist = FALSE, there is an inherent TOCTOU race between
  # path validation and the actual write. Use validate_written_path() after
  # writing to mitigate symlink-swap attacks.

  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    cli_abort("{.arg path} must be a single non-empty string.")
  }

  resolved_allowed <- normalizePath(allowed_dirs, mustWork = FALSE)

  if (must_exist) {
    resolved <- tryCatch(
      normalizePath(path, mustWork = TRUE),
      error = function(e) {
        cli_abort("Path does not exist: {.path {path}}")
      }
    )
  } else {
    parent <- dirname(path)
    resolved_parent <- tryCatch(
      normalizePath(parent, mustWork = TRUE),
      error = function(e) {
        cli_abort("Parent directory does not exist: {.path {parent}}")
      }
    )
    resolved <- file.path(resolved_parent, basename(path))
  }

  in_allowed <- vapply(resolved_allowed, function(dir) {
    startsWith(resolved, paste0(dir, "/")) || identical(resolved, dir)
  }, logical(1))

  if (!any(in_allowed)) {
    cli_abort("Path is outside allowed directories: {.path {path}}")
  }

  invisible(resolved)
}

#' Validate that a file does not exceed a size limit
#'
#' @param path Character(1). Path to the file.
#' @param max_bytes Numeric(1). Maximum allowed file size in bytes.
#' @return invisible(TRUE) on success.
#' @noRd
validate_file_size <- function(path, max_bytes) {
  size <- file.info(path)$size
  if (size > max_bytes) {
    cli_abort(
      "File size ({size} bytes) exceeds limit ({max_bytes} bytes): {.path {path}}"
    )
  }
  invisible(TRUE)
}

#' Parse a human-readable size string into bytes
#'
#' @param x Numeric or character. If numeric, returned as-is.
#'   If character, parsed from a pattern like "10MB", "1GB", "500KB", "100B".
#' @return Numeric(1). Size in bytes.
#' @noRd
parse_size <- function(x) {
  if (is.numeric(x)) {
    return(x)
  }

  if (!is.character(x) || length(x) != 1L) {
    cli_abort("Size must be a single number or a string like {.val 10MB}.")
  }

  match <- regmatches(x, regexec("^([0-9.]+)\\s*(B|KB|MB|GB)$", x, ignore.case = TRUE))[[1]]
  if (length(match) == 0L) {
    cli_abort("Unrecognized size format: {.val {x}}. Use e.g. {.val 10MB}, {.val 1GB}.")
  }

  number <- as.numeric(match[[2]])
  unit <- toupper(match[[3]])

  multiplier <- switch(unit,
    B  = 1,
    KB = 1024,
    MB = 1024^2,
    GB = 1024^3
  )

  bytes <- number * multiplier

  if (bytes <= 0) {
    cli_abort("Size must be a positive value, not {.val {x}}.")
  }

  bytes
}

#' Truncate a character string to a maximum number of characters
#'
#' @param x Character(1).
#' @param max_chars Integer(1). Maximum number of characters.
#' @return Character(1). Possibly truncated with a suffix appended.
#' @noRd
truncate_output <- function(x, max_chars = 10000) {
  if (nchar(x) <= max_chars) {
    return(x)
  }
  paste0(substr(x, 1, max_chars), "... [truncated]")
}

#' Validate a SQL identifier (column, table name)
#'
#' @param name Character(1). The identifier to validate.
#' @param allowed Character vector or NULL. If not NULL, name must be in this set
#'   (or be "*").
#' @param what Character(1). Label for error messages (e.g. "column", "table").
#' @return invisible(TRUE) on success.
#' @noRd
validate_sql_identifier <- function(name, allowed = NULL, what = "column") {
  if (!identical(name, "*")) {
    if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", name)) {
      cli_abort("Invalid {what} name: {.val {name}}")
    }
  }

  if (!is.null(allowed) && !identical(name, "*")) {
    if (!name %in% allowed) {
      cli_abort("{what} not allowed: {.val {name}}")
    }
  }

  invisible(TRUE)
}

#' Coerce a list (from JSON deserialization) to a data.frame
#'
#' When data frames are serialized through JSON IPC with
#' `simplifyVector = FALSE`, they can arrive in two forms:
#' - Row-oriented: unnamed list of named lists (each inner list = one row)
#' - Column-oriented: named list of vectors/lists (each element = one column)
#' This function detects the structure and reconstructs the data.frame.
#'
#' @param x A list from JSON deserialization.
#' @return A data.frame.
#' @noRd
coerce_list_to_df <- function(x) {
  if (!is.list(x) || length(x) == 0L) {
    cli_abort("Cannot coerce list to data.frame: unexpected structure.")
  }

  # Detect row-oriented: unnamed list where each element is a named list
  if (is.null(names(x)) && all(vapply(x, function(row) {
    is.list(row) && !is.null(names(row))
  }, logical(1)))) {
    # Row-oriented: list(list(x=1, y="a"), list(x=2, y="b"))
    col_names <- names(x[[1]])
    cols <- lapply(col_names, function(cn) {
      vals <- lapply(x, function(row) {
        val <- row[[cn]]
        if (is.null(val)) NA else val
      })
      unlist(vals)
    })
    names(cols) <- col_names
    return(as.data.frame(cols, stringsAsFactors = FALSE))
  }

  # Column-oriented: named list of vectors/lists
  if (!is.null(names(x))) {
    cols <- lapply(x, function(col) {
      if (is.list(col)) {
        col <- lapply(col, function(v) if (is.null(v)) NA else v)
        unlist(col)
      } else {
        col
      }
    })
    return(as.data.frame(cols, stringsAsFactors = FALSE))
  }

  cli_abort("Cannot coerce list to data.frame: unexpected structure.")
}

#' Re-validate a path after writing (TOCTOU mitigation)
#'
#' Call this after writing a file to verify the resolved path is still
#' within allowed directories. This mitigates symlink TOCTOU attacks
#' where the target is swapped between validation and write.
#'
#' @param path The path that was written to.
#' @param allowed_dirs Character vector of allowed directories.
#' @return invisible(TRUE) if valid.
#' @noRd
validate_written_path <- function(path, allowed_dirs) {
  if (!file.exists(path)) {
    cli_abort("Written file no longer exists at {.path {path}}.")
  }
  resolved <- normalizePath(path, mustWork = TRUE)
  norm_dirs <- normalizePath(allowed_dirs, mustWork = TRUE)
  inside <- vapply(norm_dirs, function(d) startsWith(resolved, paste0(d, "/")), logical(1))
  # Also check exact match (file directly in allowed dir root)
  exact <- vapply(norm_dirs, function(d) resolved == d, logical(1))
  if (!any(inside) && !any(exact)) {
    # Remove the potentially escaped file
    unlink(path)
    cli_abort("Written file resolved to {.path {resolved}}, which is outside allowed directories.")
  }
  invisible(TRUE)
}
