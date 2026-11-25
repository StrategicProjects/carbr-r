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

test_that("the httpfs extension is not installed without consent", {
  withr::local_options(carbr.install_httpfs = NULL, rlang_interactive = FALSE)
  local_mocked_bindings(car_httpfs_installed = function(con) FALSE)
  old <- car_env$httpfs
  car_env$httpfs <- FALSE
  withr::defer(car_env$httpfs <- old)
  expect_error(car_need_httpfs(car_con()), class = "carbr_error_httpfs")
})

test_that("car_check() classifies a batch of codes, one row per code, in the given order", {
  skip_if_not_installed("sf")
  release_teste()
  codes <- c(
    sprintf("PE-2611101-%032X", 3),     # pending
    "not a code",
    sprintf("pe-2611606-%032X", 5),     # cancelled, lower case
    sprintf("PE-2611606-%032X", 99),    # not in the publication
    sprintf("PE-2611101-%032X", 1),     # active
    sprintf("PE-2600054-%032X", 4),     # another municipality in the code
    sprintf("SP-3550308-%032X", 1)      # a state that is not published
  )
  out <- car_check(c(codes, codes[1]))
  expect_equal(nrow(out), 7)
  expect_equal(out$property_code, toupper(codes))
  expect_equal(out$check, c("attention", "invalid", "blocked", "not_found", "ok", "not_found", "not_found"))
  expect_equal(out$stage[c(1, 5)], c("waiting", "waiting"))
  expect_equal(out$area_ha[c(1, 3, 5)], c(30, 50, 10))
  expect_true(all(is.na(out$state[c(2, 4, 6, 7)])))
  expect_match(out$note[3], "cancelado")
  expect_named(out, c(
    "property_code", "check", "note", "stage", "status", "condition", "property_type",
    "size_class", "area_ha", "fiscal_modules", "state", "municipality", "created_at",
    "indigenous_share", "strict_protection_share", "sustainable_use_share", "protected_area"
  ))
  expect_equal(nrow(car_check(character())), 0)
})

test_that("the analysis stage is read from the Sicar wording", {
  expect_equal(
    car_stage(c(
      "Aguardando an\u00e1lise", "Em an\u00e1lise",
      "Analisado, aguardando atendimento a notifica\u00e7\u00e3o",
      "Aguardando an\u00e1lise, ap\u00f3s revis\u00e3o ou atendimento da notifica\u00e7\u00e3o",
      "Analisado, em conformidade com a Lei n\u00ba 12.651/2012",
      "Cancelado por decis\u00e3o administrativa", NA
    )),
    c("waiting", "analysing", "notified", "answered", "done", "cancelled", NA)
  )
})

test_that("quality indicators come per property and per municipality", {
  skip_if_not_installed("sf")
  release_teste()
  q <- car_quality("PE")
  expect_named(q, c(
    "property_code", "municipality_code", "overlap_count", "overlap_share", "outside_share",
    "indigenous_share", "strict_protection_share", "sustainable_use_share",
    "indigenous_land", "conservation_unit", "conservation_category"
  ))
  expect_equal(nrow(q), 5)
  town <- car_quality("PE", municipality = "petrolina")
  expect_equal(nrow(town), 4)
  expect_equal(sum(town$overlap_count), 2)
  expect_equal(town$property_code[town$overlap_share == 1], sprintf("PE-2611101-%032X", 1))
  expect_equal(nrow(car_quality("PE", municipality = 2611606)), 1)

  s <- car_quality_summary("PE")
  expect_equal(s$municipality, c("Petrolina", "Recife"))
  expect_equal(s$properties, c(4L, 1L))
  expect_equal(s$overlapping, c(2L, 0L))
  expect_equal(s$overlapping_half, c(1L, 0L))
  expect_equal(s$overlap_ha[1], 250)
  expect_equal(s$outside_half, c(1L, 0L))
  expect_equal(s$indigenous, c(1L, 0L))
  expect_equal(s$strict_protection, c(1L, 0L))
  expect_equal(s$sustainable_use, c(1L, 0L))
  expect_equal(nrow(car_quality_summary()), 2)
})

test_that("the check flags indigenous lands and strict protection units", {
  skip_if_not_installed("sf")
  release_teste()
  code <- sprintf("PE-2611101-%032X", c(1, 2, 3, 6))
  out <- car_check(code)
  expect_equal(out$check, c("ok", "attention", "attention", "ok"))
  expect_equal(out$indigenous_share, c(0, 0.8, 0, 0))
  expect_match(out$note[2], "(Terra Teste) em 80% da", fixed = TRUE)
  # A pending one keeps its own reason and gains the park.
  expect_match(out$note[3], "Cadastro pendente.", fixed = TRUE)
  expect_match(out$note[3], "integral (Parque Teste) em 30% da", fixed = TRUE)
  # Sustainable use is reported, but does not change the result.
  expect_match(out$note[4], "(APA: APA Teste), em toda a", fixed = TRUE)
  expect_equal(out$protected_area, c(NA, "Terra Teste", "Parque Teste", "APA Teste"))
})
