# path traversal error message

    Code
      validate_path(file.path(dir, "..", "etc", "passwd"), allowed_dirs = dir)
    Condition
      Error in `value[[3L]]()`:
      ! Path does not exist: '<TMPDIR>/../etc/passwd'

# empty path error message

    Code
      validate_path("", allowed_dirs = dir)
    Condition
      Error in `validate_path()`:
      ! `path` must be a single non-empty string.

# rate limit error message

    Code
      check_rate_limit(limiter)
    Condition
      Error in `limiter$check()`:
      ! Rate limit exceeded: maximum 1 lifetime calls.

# calculator rejection message

    Code
      tool@fn(expression = "system('whoami')")
    Condition
      Error in `validate_calc_ast()`:
      ! Function not allowed in calculator: `system()`

