test_that("the catalogue, the dictionary and the municipal summary are tibbles", {
  skip_if_not_installed("sf")
  release_teste()
  cat <- car_catalog()
  expect_equal(cat$state, "PE")
  expect_equal(cat$properties, 6L)
  expect_equal(attr(cat, "version"), "2026-01-01")
  expect_match(attr(cat, "citation"), "2026-01-01")
  expect_equal(car_dictionary()$sicar_name, "cod_imovel")
  mun <- car_municipalities("PE")
  expect_equal(mun$municipality, c("Petrolina", "Recife"))
  expect_equal(mun$properties, c(4L, 2L))
  expect_type(mun$properties, "integer")
})

test_that("car_summary() aggregates the precomputed table by any dimension", {
  skip_if_not_installed("sf")
  release_teste()
  by_size <- car_summary("size_class")
  expect_equal(by_size$size_class, c("large", "medium", "small"))
  expect_equal(by_size$properties, c(1L, 2L, 3L))
  expect_equal(by_size$area_ha, c(6000, 90, 60))
  expect_type(by_size$properties, "integer")
  total <- car_summary(NULL)
  expect_equal(dim(total), c(1L, 2L))
  expect_equal(total$properties, 6L)
  two <- car_summary(c("state", "status"), state = "PE")
  expect_equal(names(two), c("state", "status", "properties", "area_ha"))
  expect_equal(sum(two$properties), 6L)
  expect_equal(car_summary("created_year")$created_year, 2020L)
  expect_error(car_summary("municipality"))
})

test_that("car_properties() filters by municipality name or code, status, size and bbox", {
  skip_if_not_installed("sf")
  release_teste()
  expect_equal(nrow(car_properties("PE", geometry = FALSE)), 6)
  expect_equal(nrow(car_properties("pe", municipality = "PETROLINA", geometry = FALSE)), 4)
  expect_equal(nrow(car_properties("PE", municipality = 2611606, geometry = FALSE)), 2)
  expect_equal(nrow(car_properties("PE", municipality = "2611606", status = "active", geometry = FALSE)), 1)
  expect_equal(car_properties("PE", size_class = "large", geometry = FALSE)$area_ha, 6000)
  expect_equal(nrow(car_properties("PE", bbox = c(-35.1, -8.1, -34.9, -7.9), geometry = FALSE)), 2)
  expect_equal(nrow(car_properties("PE", status = "suspended", geometry = FALSE)), 0)
})

test_that("geometry comes back as sf in SIRGAS 2000, or is left out", {
  skip_if_not_installed("sf")
  release_teste()
  x <- car_properties("PE", municipality = "Recife")
  expect_s3_class(x, "sf")
  expect_equal(sf::st_crs(x)$epsg, 4674L)
  expect_true(all(sf::st_is_valid(x)))
  expect_false("geometry" %in% names(car_properties("PE", geometry = FALSE)))
})

test_that("car_property() finds codes and rejects malformed ones", {
  skip_if_not_installed("sf")
  release_teste()
  code <- sprintf("PE-2611606-%032X", 4)
  expect_equal(car_property(code, geometry = FALSE)$area_ha, 40)
  expect_equal(nrow(car_property(sprintf("PE-2611606-%032X", 99), geometry = FALSE)), 0)
  # The municipality in the code is a shortcut, not a requirement.
  moved <- sprintf("PE-2600054-%032X", 4)
  expect_equal(nrow(car_property(moved, geometry = FALSE)), 0)
  expect_error(car_property("abc"), class = "carbr_error_code")
})

test_that("car_at() returns every property that contains the point", {
  skip_if_not_installed("sf")
  release_teste()
  both <- car_at(-40.495, -9.395)
  expect_s3_class(both, "sf")
  expect_setequal(both$area_ha, c(10, 6000))
  # Inside the bounding boxes of none.
  expect_equal(nrow(car_at(-38, -8)), 0)
  expect_s3_class(car_at(-40.495, -9.395, geometry = FALSE), "tbl_df")
  expect_error(car_at(c(1, 2), 3))
})

test_that("car_tbl() is lazy and composes with dplyr", {
  skip_if_not_installed("sf")
  release_teste()
  n <- car_tbl("PE") |>
    dplyr::count(.data$size_class) |>
    dplyr::collect()
  expect_equal(sum(n$n), 6)
  expect_s3_class(car_tbl(), "tbl_lazy")
})

test_that("bad arguments fail with classed errors", {
  skip_if_not_installed("sf")
  release_teste()
  expect_error(car_properties("SP"), class = "carbr_error_state")
  expect_error(car_properties("PE", municipality = "Atlântida"), class = "carbr_error_municipality")
  expect_error(car_properties("PE", status = "ok"))
  expect_error(car_properties("PE", bbox = c(1, 2)))
})

test_that("a missing publication warns and returns the empty schema", {
  withr::local_options(carbr.base_url = file.path(tempdir(), "nao-existe"), carbr.quiet = TRUE)
  expect_warning(out <- car_properties("PE", geometry = FALSE), class = "carbr_error_http")
  expect_equal(nrow(out), 0)
  expect_true("property_code" %in% names(out))
  expect_warning(expect_equal(nrow(car_catalog()), 0), class = "carbr_error_http")
})

test_that("a file updated in place is accepted after re-reading the catalogue", {
  skip_if_not_installed("sf")
  dir <- release_teste()
  cache <- withr::local_tempdir()
  withr::local_options(
    carbr.base_url = "https://car.test/current", carbr.cache_dir = cache, carbr.max_tries = 1
  )
  served <- 0
  httr2::local_mocked_responses(function(req) {
    file <- file.path(dir, utils::URLdecode(sub("^https://car.test/current/", "", req$url)))
    served <<- served + 1
    httr2::response(status_code = 200, body = readBin(file, "raw", file.size(file)))
  })
  expect_equal(car_municipalities("PE")$properties, c(4L, 2L))

  # The publication changes: new summary file, new catalogue. The cached
  # catalogue still lists the old SHA-256.
  f_mun <- file.path(dir, "municipalities", "state=PE.parquet")
  con <- DBI::dbConnect(duckdb::duckdb())
  DBI::dbExecute(con, sprintf(
    "COPY (SELECT * REPLACE (properties + 1 AS properties) FROM read_parquet('%s'))
     TO '%s.new' (FORMAT parquet)", f_mun, f_mun
  ))
  DBI::dbDisconnect(con, shutdown = TRUE)
  file.rename(paste0(f_mun, ".new"), f_mun)
  cat <- jsonlite::fromJSON(file.path(dir, "catalog.json"), simplifyVector = FALSE)
  cat$files[[2]]$sha256 <- paste(unclass(openssl::sha256(file(f_mun))), collapse = "")
  jsonlite::write_json(cat, file.path(dir, "catalog.json"), auto_unbox = TRUE)
  unlink(file.path(cache, "2026-01-01"), recursive = TRUE)

  expect_equal(car_municipalities("PE")$properties, c(5L, 3L))

  # A file that matches no catalogue is still refused.
  writeBin(as.raw(1:10), f_mun)
  unlink(file.path(cache, "2026-01-01"), recursive = TRUE)
  expect_error(car_municipalities("PE"), class = "carbr_error_integrity")
})
