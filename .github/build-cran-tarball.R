# Build a CRAN-shaped source tarball for a secure-r-dev package.
#
# The packages keep `Remotes:` in their on-main DESCRIPTION so that
# `pak::pak("ian-flores/<pkg>")` and devtools install resolve sibling
# dependencies from GitHub. CRAN does not allow Remotes:, so this
# script makes a temporary copy of the package, strips the field, and
# runs `R CMD build` on the cleaned copy.
#
# Usage:
#   Rscript build-cran-tarball.R /path/to/<package_root>
#
# Output: <package>_<version>.tar.gz placed in the current working
# directory, with no Remotes: line in DESCRIPTION.

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) != 1L) {
    stop("usage: build-cran-tarball.R <path-to-package-root>")
  }
  pkg_path <- normalizePath(args[[1L]], mustWork = TRUE)

  staging <- file.path(tempdir(), paste0("cran-build-", basename(pkg_path)))
  unlink(staging, recursive = TRUE, force = TRUE)
  dir.create(staging, recursive = TRUE)
  file.copy(
    list.files(pkg_path, all.files = TRUE, no.. = TRUE, full.names = TRUE),
    staging,
    recursive = TRUE
  )

  desc_path <- file.path(staging, "DESCRIPTION")
  desc <- readLines(desc_path, warn = FALSE)
  remotes_start <- grep("^Remotes:", desc)
  if (length(remotes_start) == 1L) {
    end <- remotes_start
    while (end < length(desc) && grepl("^[ \t]+", desc[end + 1L])) {
      end <- end + 1L
    }
    desc <- desc[-(remotes_start:end)]
    writeLines(desc, desc_path)
    message("Stripped Remotes: lines ", remotes_start, "-", end)
  } else {
    message("No Remotes: line to strip; built unchanged.")
  }

  out_dir <- getwd()
  callr::rcmd_safe(
    "build",
    cmdargs = c("--no-manual", "--compact-vignettes=gs+qpdf", staging),
    wd = out_dir,
    show = TRUE
  )
}

if (!interactive()) main()
