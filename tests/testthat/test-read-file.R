test_that("tool_read_file reads CSV files", {
  dir <- make_test_dir()
  csv_path <- file.path(dir, "data.csv")
  write.csv(data.frame(x = 1:3, y = c("a", "b", "c")), csv_path, row.names = FALSE)

  tool <- tool_read_file(allowed_dirs = dir)
  result <- tool@fn(path = csv_path)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
  expect_equal(result$x, 1:3)
})

test_that("tool_read_file reads text files", {
  dir <- make_test_dir()
  txt_path <- file.path(dir, "notes.txt")
  writeLines(c("line1", "line2", "line3"), txt_path)

  tool <- tool_read_file(allowed_dirs = dir)
  result <- tool@fn(path = txt_path)

  expect_equal(result, c("line1", "line2", "line3"))
})

test_that("tool_read_file reads RDS files", {
  dir <- make_test_dir()
  rds_path <- file.path(dir, "obj.rds")
  saveRDS(list(a = 1, b = "hello"), rds_path)

  tool <- tool_read_file(allowed_dirs = dir)
  result <- tool@fn(path = rds_path)

  expect_equal(result, list(a = 1, b = "hello"))
})

test_that("tool_read_file reads JSON files", {
  skip_if_not_installed("jsonlite")
  dir <- make_test_dir()
  json_path <- file.path(dir, "data.json")
  writeLines('{"name": "test", "value": 42}', json_path)

  tool <- tool_read_file(allowed_dirs = dir)
  result <- tool@fn(path = json_path)

  expect_equal(result$name, "test")
  expect_equal(result$value, 42)
})

test_that("tool_read_file rejects path outside allowed_dirs", {
  dir <- make_test_dir()
  other_dir <- make_test_dir()
  txt_path <- file.path(other_dir, "secret.txt")
  writeLines("secret data", txt_path)

  tool <- tool_read_file(allowed_dirs = dir)
  expect_error(tool@fn(path = txt_path), "outside allowed directories")
})

test_that("tool_read_file rejects path traversal", {
  dir <- make_test_dir()
  # Create a file outside the allowed dir
  parent <- dirname(dir)
  outside_path <- file.path(parent, "outside.txt")
  writeLines("outside", outside_path)
  withr::defer(unlink(outside_path))

  tool <- tool_read_file(allowed_dirs = dir)
  traversal_path <- file.path(dir, "..", "outside.txt")
  expect_error(tool@fn(path = traversal_path), "outside allowed directories")
})

test_that("tool_read_file rejects file exceeding size limit", {
  dir <- make_test_dir()
  big_path <- file.path(dir, "big.txt")
  # Write a file larger than 100 bytes
  writeLines(strrep("x", 200), big_path)

  tool <- tool_read_file(allowed_dirs = dir, max_file_size = 100)
  expect_error(tool@fn(path = big_path), "exceeds limit")
})

test_that("detect_format identifies common extensions", {
  expect_equal(securetools:::detect_format("file.csv"), "csv")
  expect_equal(securetools:::detect_format("file.json"), "json")
  expect_equal(securetools:::detect_format("file.txt"), "txt")
  expect_equal(securetools:::detect_format("file.rds"), "rds")
  expect_equal(securetools:::detect_format("file.xlsx"), "xlsx")
  expect_equal(securetools:::detect_format("file.parquet"), "parquet")
})

test_that("detect_format errors on unknown extension", {
  expect_error(securetools:::detect_format("file.xyz"), "Cannot auto-detect")
})

test_that("tool_read_file explicit format overrides auto-detection", {
  dir <- make_test_dir()
  # File has .dat extension but contains CSV
  dat_path <- file.path(dir, "data.dat")
  write.csv(data.frame(x = 1:2), dat_path, row.names = FALSE)

  tool <- tool_read_file(allowed_dirs = dir)
  result <- tool@fn(path = dat_path, format = "csv")

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
})

test_that("tool_read_file rate limiting works", {
  dir <- make_test_dir()
  txt_path <- file.path(dir, "data.txt")
  writeLines("hello", txt_path)

  tool <- tool_read_file(allowed_dirs = dir, max_calls = 2)
  tool@fn(path = txt_path)
  tool@fn(path = txt_path)
  expect_error(tool@fn(path = txt_path), "Rate limit")
})

test_that("tool_read_file errors on unsupported format", {
  dir <- make_test_dir()
  txt_path <- file.path(dir, "data.txt")
  writeLines("hello", txt_path)

  tool <- tool_read_file(allowed_dirs = dir)
  expect_error(tool@fn(path = txt_path, format = "hdf5"), "Unsupported format")
})

test_that("tool_read_file returns securer_tool object", {
  dir <- make_test_dir()
  tool <- tool_read_file(allowed_dirs = dir)
  expect_s3_class(tool, "securer::securer_tool")
  expect_equal(tool@name, "read_file")
})

test_that("tool_read_file rejects nonexistent file", {
  dir <- make_test_dir()
  tool <- tool_read_file(allowed_dirs = dir)
  expect_error(tool@fn(path = file.path(dir, "nope.csv")), "does not exist")
})

test_that("tool_read_file handles empty text file", {
  dir <- withr::local_tempdir()
  f <- file.path(dir, "empty.txt")
  file.create(f)
  tool <- tool_read_file(allowed_dirs = dir)
  result <- tool@fn(path = f)
  expect_true(length(result) == 0L || (length(result) == 1L && result == ""))
})
