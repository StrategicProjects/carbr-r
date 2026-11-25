## Submission

This is a new package: a client for the rural properties declared in the
Rural Environmental Registry of Brazil ('Cadastro Ambiental Rural', 'CAR'),
public data of the Brazilian Forest Service (<https://www.car.gov.br/>),
republished as 'GeoParquet' so that queries read only the parts of the
remote files they need.

## R CMD check results

0 errors | 0 warnings | 0 notes locally (macOS, R 4.6.0), also with
`_R_CHECK_DEPENDS_ONLY_=true`, and on GitHub Actions (Windows release;
Ubuntu release, devel and oldrel-1).

With the CRAN incoming checks, the only NOTE is the expected "New
submission".

## Notes for reviewers

* The package reads public government open data. No authentication is
  required. The address of the publication can be changed with
  `options(carbr.base_url = )` or the `CAR_URL` environment variable.
* Remote 'Parquet' files are read with 'duckdb' and its official 'httpfs'
  extension (MIT), which 'duckdb' downloads from its own extension
  repository into its own extension folder. The package never installs it
  without the user's consent: in interactive sessions it asks before the
  first remote read; elsewhere it stops with a message pointing to
  `car_install_httpfs()` (or `options(carbr.install_httpfs = TRUE)`).
  Nothing in the examples, tests or vignettes triggers the installation.
* Small files (the catalogue and the precomputed summaries) are cached
  under `tools::R_user_dir("carbr", "cache")`, as required by CRAN policy,
  and can be removed with `car_cache_clear()`. Property files are never
  copied to disk.
* All examples that reach the internet are guarded with
  `@examplesIf interactive()`. The vignettes are precompiled (the executable
  sources are `.Rmd.orig` files excluded from the build), so building them
  needs no network. The tests run against a small publication written to a
  temporary folder and against mocked responses.
* Network failures are handled gracefully: the functions warn and return an
  empty result with the documented columns.
* The documentation is in Portuguese (`Language: pt-BR`), the language of
  the data and of its users; messages and the DESCRIPTION are in English.
