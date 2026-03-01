test_that("plot_tool generates a PNG file", {
  dir <- withr::local_tempdir()
  tool <- plot_tool(allowed_dirs = dir)
  path <- file.path(dir, "test.png")

  result <- tool@fn(
    path = path,
    plot_code = "plot(1:10, 1:10, main = 'Test')"
  )

  expect_true(file.exists(path))
  expect_true(result$size > 0)
  expect_equal(result$format, "png")
})

test_that("plot_tool generates a PDF file", {
  dir <- withr::local_tempdir()
  tool <- plot_tool(allowed_dirs = dir)
  path <- file.path(dir, "test.pdf")

  result <- tool@fn(path = path, plot_code = "plot(1:5)")
  expect_true(file.exists(path))
  expect_equal(result$format, "pdf")
})

test_that("plot_tool rejects path outside allowed dirs", {
  dir <- withr::local_tempdir()
  tool <- plot_tool(allowed_dirs = dir)

  other_dir <- withr::local_tempdir()
  path <- file.path(other_dir, "evil.png")

  expect_error(
    tool@fn(path = path, plot_code = "plot(1)"),
    "outside allowed"
  )
})

test_that("plot_tool uses default dimensions", {
  dir <- withr::local_tempdir()
  tool <- plot_tool(allowed_dirs = dir, default_width = 4, default_height = 3)
  path <- file.path(dir, "test.png")

  result <- tool@fn(path = path, plot_code = "plot(1:5)")
  expect_true(file.exists(path))
})

test_that("plot_tool handles plot code errors", {
  dir <- withr::local_tempdir()
  tool <- plot_tool(allowed_dirs = dir)
  path <- file.path(dir, "fail.png")

  # stop() is not in the allowed function list, so AST validation rejects it
  expect_error(
    tool@fn(path = path, plot_code = "stop('intentional error')"),
    "[Nn]ot allowed"
  )
})

test_that("plot_tool rate limiting works", {
  dir <- withr::local_tempdir()
  tool <- plot_tool(allowed_dirs = dir, max_calls = 1)

  tool@fn(path = file.path(dir, "a.png"), plot_code = "plot(1)")
  expect_error(
    tool@fn(path = file.path(dir, "b.png"), plot_code = "plot(1)"),
    "Rate limit"
  )
})

test_that("plot_tool rejects system() in plot_code", {
  dir <- withr::local_tempdir()
  tool <- plot_tool(allowed_dirs = dir)
  path <- file.path(dir, "evil.png")
  expect_error(
    tool@fn(path = path, plot_code = "system('whoami')"),
    "[Nn]ot allowed"
  )
})

test_that("plot_tool rejects file.remove() in plot_code", {
  dir <- withr::local_tempdir()
  tool <- plot_tool(allowed_dirs = dir)
  path <- file.path(dir, "evil.png")
  expect_error(
    tool@fn(path = path, plot_code = "file.remove('important.txt')"),
    "[Nn]ot allowed"
  )
})

test_that("plot_tool rejects Sys.getenv() in plot_code", {
  dir <- withr::local_tempdir()
  tool <- plot_tool(allowed_dirs = dir)
  path <- file.path(dir, "evil.png")
  expect_error(
    tool@fn(path = path, plot_code = "Sys.getenv('SECRET')"),
    "[Nn]ot allowed"
  )
})

test_that("plot_tool allows legitimate plotting code", {
  dir <- withr::local_tempdir()
  tool <- plot_tool(allowed_dirs = dir)
  path <- file.path(dir, "ok.png")
  result <- tool@fn(path = path, plot_code = "plot(1:10, main = 'Test')")
  expect_true(file.exists(path))
})

test_that("plot_tool returns securer_tool object", {
  dir <- withr::local_tempdir()
  tool <- plot_tool(allowed_dirs = dir)
  expect_s3_class(tool, "securer::securer_tool")
  expect_equal(tool@name, "plot")
})

test_that("plot_tool rejects symlink escape", {
  skip_on_os("windows")
  dir <- withr::local_tempdir()
  outside <- withr::local_tempdir()
  link <- file.path(dir, "escape")
  file.symlink(outside, link)
  tool <- plot_tool(allowed_dirs = dir)
  expect_error(
    tool@fn(path = file.path(link, "evil.png"), plot_code = "plot(1)"),
    "[Oo]utside|not allowed"
  )
})
