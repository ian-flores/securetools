# tests/testthat/test-utils-validate.R

# -- validate_path ---------------------------------------------------------

test_that("validate_path accepts path within allowed dir", {
  dir <- withr::local_tempdir()
  f <- file.path(dir, "ok.txt")
  writeLines("hello", f)

  resolved <- validate_path(f, allowed_dirs = dir)
  expect_true(file.exists(resolved))
})

test_that("validate_path rejects path outside allowed dir", {
  dir1 <- withr::local_tempdir()
  dir2 <- withr::local_tempdir()
  f <- file.path(dir2, "secret.txt")
  writeLines("secret", f)

  expect_error(
    validate_path(f, allowed_dirs = dir1),
    "outside allowed directories"
  )
})

test_that("validate_path rejects ../ traversal", {
  dir <- withr::local_tempdir()
  sub <- file.path(dir, "sub")
  dir.create(sub)
  outside <- file.path(dir, "outside.txt")
  writeLines("x", outside)

  # ../outside.txt resolves to dir/outside.txt which is inside dir,

  # but NOT inside sub -- so only allow sub

  expect_error(
    validate_path(file.path(sub, "..", "outside.txt"), allowed_dirs = sub),
    "outside allowed directories"
  )
})

test_that("validate_path rejects symlink escape", {
  skip_on_os("windows")

  allowed <- withr::local_tempdir()
  outside <- withr::local_tempdir()
  secret <- file.path(outside, "secret.txt")
  writeLines("secret", secret)

  # Create symlink inside allowed dir pointing outside
  link <- file.path(allowed, "escape")
  file.symlink(secret, link)

  expect_error(
    validate_path(link, allowed_dirs = allowed),
    "outside allowed directories"
  )
})

test_that("validate_path errors for non-existent path when must_exist = TRUE", {
  dir <- withr::local_tempdir()

  expect_error(
    validate_path(file.path(dir, "nope.txt"), allowed_dirs = dir, must_exist = TRUE),
    "does not exist"
  )
})

test_that("validate_path with must_exist = FALSE allows new file in allowed dir", {
  dir <- withr::local_tempdir()

  resolved <- validate_path(
    file.path(dir, "new_file.txt"),
    allowed_dirs = dir,
    must_exist = FALSE
  )
  expect_true(startsWith(resolved, normalizePath(dir)))
})

test_that("validate_path with must_exist = FALSE rejects new file outside allowed dir", {
  dir1 <- withr::local_tempdir()
  dir2 <- withr::local_tempdir()

  expect_error(
    validate_path(file.path(dir2, "new.txt"), allowed_dirs = dir1, must_exist = FALSE),
    "outside allowed directories"
  )
})

test_that("validate_path with must_exist = FALSE errors if parent dir does not exist", {
  dir <- withr::local_tempdir()

  expect_error(
    validate_path(file.path(dir, "no_such_dir", "file.txt"), allowed_dirs = dir, must_exist = FALSE),
    "Parent directory does not exist"
  )
})

# -- validate_file_size ----------------------------------------------------

test_that("validate_file_size passes when under limit", {
  dir <- withr::local_tempdir()
  f <- file.path(dir, "small.txt")
  writeLines("hi", f)

  expect_true(validate_file_size(f, max_bytes = 1e6))
})

test_that("validate_file_size fails when over limit", {
  dir <- withr::local_tempdir()
  f <- file.path(dir, "big.txt")
  writeBin(raw(1000), f)

  expect_error(
    validate_file_size(f, max_bytes = 500),
    "exceeds limit"
  )
})

# -- parse_size ------------------------------------------------------------

test_that("parse_size handles MB", {
  expect_equal(parse_size("10MB"), 10 * 1024^2)
})

test_that("parse_size handles GB", {
  expect_equal(parse_size("1GB"), 1024^3)
})

test_that("parse_size handles KB", {
  expect_equal(parse_size("500KB"), 500 * 1024)
})

test_that("parse_size handles B", {
  expect_equal(parse_size("100B"), 100)
})

test_that("parse_size is case insensitive", {
  expect_equal(parse_size("10mb"), 10 * 1024^2)
  expect_equal(parse_size("1gb"), 1024^3)
})

test_that("parse_size passes through numeric", {
  expect_equal(parse_size(42), 42)
})

test_that("parse_size errors on bad format", {
  expect_error(parse_size("10XB"), "Unrecognized size format")
  expect_error(parse_size("lots"), "Unrecognized size format")
})

# -- truncate_output -------------------------------------------------------

test_that("truncate_output returns short string unchanged", {
  expect_equal(truncate_output("hello", max_chars = 100), "hello")
})

test_that("truncate_output truncates long string", {
  long <- paste(rep("a", 200), collapse = "")
  result <- truncate_output(long, max_chars = 50)
  expect_equal(nchar(result), 50 + nchar("... [truncated]"))
  expect_true(endsWith(result, "... [truncated]"))
  expect_equal(substr(result, 1, 50), paste(rep("a", 50), collapse = ""))
})

# -- validate_sql_identifier -----------------------------------------------

test_that("validate_sql_identifier accepts valid names", {
  expect_true(validate_sql_identifier("col_name"))
  expect_true(validate_sql_identifier("x"))
  expect_true(validate_sql_identifier("_private"))
  expect_true(validate_sql_identifier("Col123"))
})

test_that("validate_sql_identifier accepts *", {
  expect_true(validate_sql_identifier("*"))
})

test_that("validate_sql_identifier rejects SQL injection patterns", {
  expect_error(validate_sql_identifier("DROP TABLE"), "Invalid column name")
  expect_error(validate_sql_identifier("col; --"), "Invalid column name")
  expect_error(validate_sql_identifier("1col"), "Invalid column name")
  expect_error(validate_sql_identifier("col'OR 1=1"), "Invalid column name")
})

test_that("validate_sql_identifier respects allow-list", {
  expect_true(validate_sql_identifier("name", allowed = c("name", "age")))
  expect_error(
    validate_sql_identifier("secret", allowed = c("name", "age")),
    "not allowed"
  )
})

test_that("validate_sql_identifier * bypasses allow-list", {
  expect_true(validate_sql_identifier("*", allowed = c("name", "age")))
})

test_that("validate_sql_identifier uses custom 'what' label", {
  expect_error(
    validate_sql_identifier("1bad", what = "table"),
    "Invalid table name"
  )
})
