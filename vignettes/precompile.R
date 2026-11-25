# Precompile the network-dependent vignettes.
#
# The vignettes read the published data, so they cannot be built on CRAN or
# CI. The executable source lives in *.Rmd.orig; this script knits it locally
# into the *.Rmd that ships with the package, with output and figures baked
# in. Run it from the package root whenever a .Rmd.orig or the published
# data change, and commit the regenerated .Rmd files and figures.
#
# Usage: Rscript vignettes/precompile.R [name ...]

vignettes <- commandArgs(trailingOnly = TRUE)
if (length(vignettes) == 0) vignettes <- c("carbr", "inconsistencias", "analise")

pkgload::load_all(quiet = TRUE)
invisible(car_catalog(refresh = TRUE))
withr::with_dir("vignettes", {
  for (v in vignettes) {
    knitr::knit(paste0(v, ".Rmd.orig"), output = paste0(v, ".Rmd"))
  }
})
