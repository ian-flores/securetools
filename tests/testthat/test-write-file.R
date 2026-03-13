test_that("tool_write_file writes CSV from data frame", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir)
  out <- file.path(dir, "data.csv")

  result <- tool@fn(path = out, content = iris[1:3, ])

  expect_true(file.exists(out))
  df <- utils::read.csv(out)
  expect_equal(nrow(df), 3)
  expect_equal(result$format, "csv")
})

test_that("tool_write_file writes JSON", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir)
  out <- file.path(dir, "data.json")

  result <- tool@fn(path = out, content = list(a = 1, b = "hello"))

  expect_true(file.exists(out))
  parsed <- jsonlite::fromJSON(out)
  expect_equal(parsed$a, 1)
  expect_equal(parsed$b, "hello")
  expect_equal(result$format, "json")
})

test_that("tool_write_file writes text", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir)
  out <- file.path(dir, "notes.txt")

  result <- tool@fn(path = out, content = c("line 1", "line 2"))

  expect_true(file.exists(out))
  lines <- readLines(out)
  expect_equal(lines, c("line 1", "line 2"))
  expect_equal(result$format, "txt")
})

test_that("tool_write_file writes RDS", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir)
  out <- file.path(dir, "model.rds")

  payload <- list(x = 1:10, y = letters[1:5])
  result <- tool@fn(path = out, content = payload)

  expect_true(file.exists(out))
  loaded <- readRDS(out)
  expect_equal(loaded, payload)
  expect_equal(result$format, "rds")
})

test_that("tool_write_file rejects path outside allowed dirs", {
  dir <- make_test_dir()
  other <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir)

  expect_error(
    tool@fn(path = file.path(other, "bad.txt"), content = "nope"),
    "outside allowed"
  )
})

test_that("tool_write_file rejects overwrite when overwrite = FALSE", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir, overwrite = FALSE)
  out <- file.path(dir, "existing.txt")
  writeLines("original", out)

  expect_error(
    tool@fn(path = out, content = "new"),
    "already exists"
  )
  # Original content unchanged
  expect_equal(readLines(out), "original")
})

test_that("tool_write_file allows overwrite when overwrite = TRUE", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir, overwrite = TRUE)
  out <- file.path(dir, "existing.txt")
  writeLines("original", out)

  tool@fn(path = out, content = "updated")
  expect_equal(readLines(out), "updated")
})

test_that("tool_write_file enforces size limit", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir, max_file_size = "100B")

  # Create content larger than 100 bytes
  big <- paste(rep("x", 200), collapse = "")
  expect_error(
    tool@fn(path = file.path(dir, "big.txt"), content = big),
    "exceeds limit"
  )
  # File should not exist at target
  expect_false(file.exists(file.path(dir, "big.txt")))
})

test_that("tool_write_file auto-detects format from extension", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir)

  # csv
  result_csv <- tool@fn(
    path = file.path(dir, "out.csv"),
    content = data.frame(x = 1:2)
  )
  expect_equal(result_csv$format, "csv")

  # json
  result_json <- tool@fn(
    path = file.path(dir, "out.json"),
    content = list(val = TRUE)
  )
  expect_equal(result_json$format, "json")

  # txt
  result_txt <- tool@fn(
    path = file.path(dir, "out.txt"),
    content = "hi"
  )
  expect_equal(result_txt$format, "txt")

  # rds
  result_rds <- tool@fn(
    path = file.path(dir, "out.rds"),
    content = list(1)
  )
  expect_equal(result_rds$format, "rds")
})

test_that("tool_write_file rejects unknown extension in auto mode", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir)

  expect_error(
    tool@fn(path = file.path(dir, "out.xyz"), content = "data"),
    "auto-detect"
  )
})

test_that("tool_write_file rate limiting works", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir, max_calls = 2)

  tool@fn(path = file.path(dir, "a.txt"), content = "a")
  tool@fn(path = file.path(dir, "b.txt"), content = "b")
  expect_error(
    tool@fn(path = file.path(dir, "c.txt"), content = "c"),
    "Rate limit"
  )
})

test_that("tool_write_file returns securer_tool object", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir)
  expect_s3_class(tool, "securer::securer_tool")
  expect_equal(tool@name, "write_file")
})

test_that("tool_write_file CSV rejects non-data-frame content", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir)

  expect_error(
    tool@fn(path = file.path(dir, "bad.csv"), content = "not a df"),
    "data frame"
  )
})

test_that("tool_write_file explicit format overrides extension", {
  dir <- make_test_dir()
  tool <- tool_write_file(allowed_dirs = dir)

  # Write text content to a .dat file using explicit format
  tool@fn(path = file.path(dir, "out.txt"), content = "hello", format = "txt")
  expect_equal(readLines(file.path(dir, "out.txt")), "hello")
})

test_that("tool_write_file rejects path traversal", {
  dir <- withr::local_tempdir()
  tool <- tool_write_file(allowed_dirs = dir)
  expect_error(
    tool@fn(path = file.path(dir, "..", "escaped.txt"), content = "evil", format = "txt"),
    "[Oo]utside|not allowed"
  )
})

test_that("tool_write_file rejects symlink escape", {
  skip_on_os("windows")
  dir <- withr::local_tempdir()
  outside <- withr::local_tempdir()
  link <- file.path(dir, "escape")
  file.symlink(outside, link)
  tool <- tool_write_file(allowed_dirs = dir)
  expect_error(
    tool@fn(path = file.path(link, "evil.txt"), content = "data", format = "txt"),
    "[Oo]utside|not allowed"
  )
})

test_that("validate_written_path catches post-write symlink escape", {
  skip_on_os("windows")
  allowed <- withr::local_tempdir()
  outside <- withr::local_tempdir()

  # Simulate: a file is written inside allowed dir, but real path is outside
  real_file <- file.path(outside, "escaped.txt")
  writeLines("data", real_file)
  link <- file.path(allowed, "link.txt")
  file.symlink(real_file, link)

  expect_error(
    securetools:::validate_written_path(link, allowed),
    "[Oo]utside"
  )
  # validate_written_path should have removed the symlink target
  expect_false(file.exists(link))
})
