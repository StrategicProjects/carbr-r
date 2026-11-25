# Precompile the network-dependent vignette.
#
# The vignette reads the published data, so it cannot be built on CRAN or
# CI. The executable source lives in carbr.Rmd.orig; this script knits it
# locally into the carbr.Rmd that ships with the package, with output and
# figures baked in. Run it from the package root whenever the .Rmd.orig or
# the published data change, and commit the regenerated .Rmd and figures.
#
# Usage: Rscript vignettes/precompile.R

pkgload::load_all(quiet = TRUE)
invisible(car_catalog(refresh = TRUE))
withr::with_dir("vignettes", {
  knitr::knit("carbr.Rmd.orig", output = "carbr.Rmd")
})
