test_that("tool_plot generates a PNG file", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)
  path <- file.path(dir, "test.png")

  result <- tool@fn(
    path = path,
    plot_code = "plot(1:10, 1:10, main = 'Test')"
  )

  expect_true(file.exists(path))
  expect_true(result$size > 0)
  expect_equal(result$format, "png")
})

test_that("tool_plot generates a PDF file", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)
  path <- file.path(dir, "test.pdf")

  result <- tool@fn(path = path, plot_code = "plot(1:5)")
  expect_true(file.exists(path))
  expect_equal(result$format, "pdf")
})

test_that("tool_plot rejects path outside allowed dirs", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)

  other_dir <- withr::local_tempdir()
  path <- file.path(other_dir, "evil.png")

  expect_error(
    tool@fn(path = path, plot_code = "plot(1)"),
    "outside allowed"
  )
})

test_that("tool_plot uses default dimensions", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir, default_width = 4, default_height = 3)
  path <- file.path(dir, "test.png")

  result <- tool@fn(path = path, plot_code = "plot(1:5)")
  expect_true(file.exists(path))
})

test_that("tool_plot handles plot code errors", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)
  path <- file.path(dir, "fail.png")

  # stop() is not in the allowed function list, so AST validation rejects it
  expect_error(
    tool@fn(path = path, plot_code = "stop('intentional error')"),
    "[Nn]ot allowed"
  )
})

test_that("tool_plot rate limiting works", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir, max_calls = 1)

  tool@fn(path = file.path(dir, "a.png"), plot_code = "plot(1)")
  expect_error(
    tool@fn(path = file.path(dir, "b.png"), plot_code = "plot(1)"),
    "Rate limit"
  )
})

test_that("tool_plot rejects system() in plot_code", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)
  path <- file.path(dir, "evil.png")
  expect_error(
    tool@fn(path = path, plot_code = "system('whoami')"),
    "[Nn]ot allowed"
  )
})

test_that("tool_plot rejects file.remove() in plot_code", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)
  path <- file.path(dir, "evil.png")
  expect_error(
    tool@fn(path = path, plot_code = "file.remove('important.txt')"),
    "[Nn]ot allowed"
  )
})

test_that("tool_plot rejects Sys.getenv() in plot_code", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)
  path <- file.path(dir, "evil.png")
  expect_error(
    tool@fn(path = path, plot_code = "Sys.getenv('SECRET')"),
    "[Nn]ot allowed"
  )
})

test_that("tool_plot allows legitimate plotting code", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)
  path <- file.path(dir, "ok.png")
  result <- tool@fn(path = path, plot_code = "plot(1:10, main = 'Test')")
  expect_true(file.exists(path))
})

test_that("tool_plot returns securer_tool object", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)
  expect_s3_class(tool, "securer::securer_tool")
  expect_equal(tool@name, "plot")
})

test_that("tool_plot rejects symlink escape", {
  skip_on_os("windows")
  dir <- withr::local_tempdir()
  outside <- withr::local_tempdir()
  link <- file.path(dir, "escape")
  file.symlink(outside, link)
  tool <- tool_plot(allowed_dirs = dir)
  expect_error(
    tool@fn(path = file.path(link, "evil.png"), plot_code = "plot(1)"),
    "[Oo]utside|not allowed"
  )
})

# --- Indirection bypasses: none of these may run code or write a file ---

plot_bypass_variants <- function(marker) {
  cmd <- paste("touch", shQuote(marker))
  q <- function(x) encodeString(x, quote = "'")
  c(
    do_call      = sprintf("do.call('system', list(%s)); plot(1)", q(cmd)),
    do_call_sym  = sprintf("do.call(system, list(%s)); plot(1)", q(cmd)),
    lapply_sym   = sprintf("lapply(%s, system); plot(1)", q(cmd)),
    sapply_str   = sprintf("sapply(%s, 'system'); plot(1)", q(cmd)),
    map          = sprintf("Map(system, %s); plot(1)", q(cmd)),
    reduce       = sprintf("Reduce(system, %s); plot(1)", q(cmd)),
    string_call  = sprintf("'system'(%s); plot(1)", q(cmd)),
    backtick     = sprintf("`system`(%s); plot(1)", q(cmd)),
    paren_call   = sprintf("(system)(%s); plot(1)", q(cmd)),
    alias        = sprintf("f <- system; f(%s); plot(1)", q(cmd)),
    list_call    = sprintf("x <- list(f = system); x$f(%s); plot(1)", q(cmd)),
    index_call   = sprintf("x <- list(system); x[[1]](%s); plot(1)", q(cmd)),
    dcolon       = sprintf("base::system(%s); plot(1)", q(cmd)),
    tcolon       = sprintf("base:::system(%s); plot(1)", q(cmd)),
    match_fun    = sprintf("match.fun('system')(%s); plot(1)", q(cmd)),
    get          = sprintf("get('system')(%s); plot(1)", q(cmd)),
    get_function = sprintf("getFunction('system')(%s); plot(1)", q(cmd)),
    eval_parse   = sprintf("eval(parse(text = %s)); plot(1)",
                           q(sprintf("system(%s)", q(cmd)))),
    pairs_panel  = sprintf(
      "pairs(matrix(1:4, 2), panel = 'system', labels = c(%s, 'b'))", q(cmd)
    ),
    with_env     = sprintf("with(list(s = system), s(%s)); plot(1)", q(cmd))
  )
}

test_that("tool_plot blocks indirect calls to non-allowed functions", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)
  marker <- file.path(dir, "pwned")

  for (nm in names(plot_bypass_variants(marker))) {
    code <- plot_bypass_variants(marker)[[nm]]
    unlink(marker)
    expect_error(
      tool@fn(path = file.path(dir, paste0(nm, ".png")), plot_code = code),
      info = nm
    )
    expect_false(file.exists(marker), info = nm)
  }
})

test_that("tool_plot does not expose the global or base environment", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)
  assign(".securetools_secret", "leak", envir = globalenv())
  withr::defer(rm(".securetools_secret", envir = globalenv()))

  expect_error(
    tool@fn(path = file.path(dir, "a.png"),
            plot_code = "plot(1, main = .securetools_secret)")
  )
  # A non-allowed base function referenced as a value is not reachable
  expect_error(
    tool@fn(path = file.path(dir, "b.png"),
            plot_code = "x <- Sys.getenv; plot(1)")
  )
})

test_that("tool_plot blocks string `ties` lookups in approx() and spline()", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)
  marker <- file.path(dir, "pwned")

  # stats resolves `ties` with match.fun() from inside its own namespace,
  # which reaches the global environment. A probe there must never run.
  assign(".securetools_probe", function(...) {
    file.create(marker)
    1
  }, envir = globalenv())
  withr::defer(rm(".securetools_probe", envir = globalenv()))

  codes <- c(
    approx = "approx(c(1, 1, 2), c(1, 2, 3), ties = '.securetools_probe'); plot(1)",
    approx_partial = "approx(c(1, 1, 2), c(1, 2, 3), ti = '.securetools_probe'); plot(1)",
    approx_pos = paste0(
      "approx(c(1, 1, 2), c(1, 2, 3), NULL, 'linear', 50, NA, NA, 1, 0, ",
      "'.securetools_probe'); plot(1)"
    ),
    approxfun = "approxfun(c(1, 1, 2), c(1, 2, 3), ties = '.securetools_probe'); plot(1)",
    spline = "spline(c(1, 1, 2), c(1, 2, 3), ties = '.securetools_probe'); plot(1)",
    splinefun = "splinefun(c(1, 1, 2), c(1, 2, 3), ties = '.securetools_probe'); plot(1)",
    paste_name = "approx(c(1, 1, 2), c(1, 2, 3), ties = paste0('.securetools', '_probe')); plot(1)",
    with_shadow = paste0(
      "with(list(mean = '.securetools_probe'), ",
      "approx(c(1, 1, 2), c(1, 2, 3), ties = mean)); plot(1)"
    )
  )
  for (nm in names(codes)) {
    unlink(marker)
    expect_error(
      tool@fn(path = file.path(dir, paste0(nm, ".png")), plot_code = codes[[nm]]),
      info = nm
    )
    expect_false(file.exists(marker), info = nm)
  }

  # The default and ties = "ordered" still work
  res <- tool@fn(
    path = file.path(dir, "ok.png"),
    plot_code = "a <- approx(1:3, c(2, 4, 3), ties = 'ordered'); plot(a)"
  )
  expect_true(file.exists(res$path))
})

test_that("tool_plot runs common graphics, grDevices, and stats functions", {
  dir <- withr::local_tempdir()
  tool <- tool_plot(allowed_dirs = dir)

  codes <- c(
    hist = "hist(rnorm(100), main = 'Histogram')",
    lines = "plot(1:10, type = 'n'); lines(1:10, (1:10)^2 / 10); points(1:10, 1:10)",
    barplot = "barplot(c(a = 3, b = 5, c = 2), col = 'steelblue')",
    boxplot_formula = "d <- data.frame(g = rep(c('a', 'b'), 5), v = 1:10); boxplot(v ~ g, data = d)",
    plot_formula = "d <- data.frame(x = 1:10, y = (1:10)^2); plot(y ~ x, data = d); lines(y ~ x, data = d)",
    density_curve = "hist(rnorm(50), freq = FALSE); curve(dnorm(x), add = TRUE); abline(h = 0)",
    legend_text = "plot(1:5); legend('topleft', legend = c('a', 'b'), col = 1:2, lty = 1); text(2, 2, 'hi')",
    pairs_heatmap = "pairs(matrix(rnorm(30), 10)); heatmap(matrix(rnorm(25), 5))",
    approx_spline = "a <- approx(1:5, c(2, 4, 3, 5, 1)); s <- spline(1:5, c(2, 4, 3, 5, 1)); plot(a); lines(s)"
  )
  for (nm in names(codes)) {
    path <- file.path(dir, paste0(nm, ".png"))
    res <- tool@fn(path = path, plot_code = codes[[nm]])
    expect_true(file.exists(path), info = nm)
    expect_gt(res$size, 0)
  }
})
