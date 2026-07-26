# Releasing secure-r-dev packages to CRAN

CRAN forbids `Remotes:` in `DESCRIPTION`, but the secure-r-dev
component packages list each other in `Remotes:` so
`pak::pak("ian-flores/<pkg>")` works for non-CRAN consumers. This
document describes the submission flow.

(Ported from the retired `secureverse` umbrella repo,
`inst/release/RELEASING.md`, and updated for the 4-package lineup.)

## Submission order

CRAN accepts a package only if all its dependencies are already
available. Submit in this order, waiting for each to land before the
next:

1. `securer`
2. `secureguard` (depends on securer)
3. `securetools` (depends on securer; soft on secureguard)
4. `securebench` (soft on secureguard)

Soft = `Suggests`. Submission can technically proceed before Suggests
land, but vignettes that exercise the soft dep won't build cleanly.

Note: `securetools` emits optional OpenTelemetry spans via the CRAN
`otel` package (with `otelsdk` used only in tests) and carries a soft
reference to `orchestr` (agent-integration vignette). Neither blocks
CRAN submission of `securetools` itself, but any Suggests package
referenced from vignettes/tests must either be on CRAN or the usage
must degrade gracefully (`skip_if_not_installed()`, `eval = FALSE`
chunks).

## Building the CRAN tarball

```sh
Rscript .github/build-cran-tarball.R /path/to/securetools
# -> securetools_<version>.tar.gz in cwd, with Remotes: stripped
```

The script clones the package into `tempdir()`, removes the `Remotes:`
block, and runs `R CMD build` with CRAN-friendly flags. The on-disk
package is untouched.

## Final pre-submission checks

```sh
R CMD check --as-cran securetools_<version>.tar.gz
```

Should report `Status: OK` (0 errors, 0 warnings, 0 notes). CI on each
repo already runs `--as-cran` and is required to be green.

For a wider matrix:

```r
rhub::check_for_cran("securetools_<version>.tar.gz")
devtools::check_win_devel("securetools_<version>.tar.gz")
```

## Submission

Upload the tarball at <https://cran.r-project.org/submit.html>. The
text in `cran-comments.md` is what you paste into the "comments"
field.

## After acceptance

Tag the released commit on GitHub (`git tag v<version>-cran`) so the
on-main `Remotes:` reference resolves to a known-CRAN-published version
even for downstream non-CRAN packages still depending on the GitHub
form.
