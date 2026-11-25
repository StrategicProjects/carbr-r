# A tiny publication on disk: six square properties in two municipalities,
# written with the same layout and columns as the real one.

square_wkb <- function(x, y, side = 0.01) {
  ring <- rbind(c(x, y), c(x + side, y), c(x + side, y + side), c(x, y + side), c(x, y))
  sf::st_as_binary(sf::st_multipolygon(list(list(ring))))
}

release_teste <- function(env = parent.frame()) {
  testthat::skip_if_not_installed("blob")
  testthat::skip_if_not_installed("sf")
  dir <- withr::local_tempdir(.local_envir = env)
  x <- c(-40.50, -40.48, -40.46, -35.00, -34.98, -40.50)
  y <- c(-9.40, -9.40, -9.40, -8.00, -8.00, -9.40)
  props <- data.frame(
    property_code = sprintf("PE-%s-%032X", rep(c("2611101", "2611606", "2611101"), c(3, 2, 1)), 1:6),
    status_code = c("AT", "AT", "PE", "AT", "CA", "AT"),
    status = c("active", "active", "pending", "active", "cancelled", "active"),
    condition = "Aguardando análise",
    property_type_code = "IRU", property_type = "rural_property",
    created_at = as.POSIXct("2020-06-01", tz = "UTC"),
    area_ha = c(10, 20, 30, 40, 50, 6000),
    fiscal_modules = c(0.2, 0.4, 0.6, 5, 6, 100),
    size_class = c("small", "small", "small", "medium", "medium", "large"),
    state = "PE",
    municipality = rep(c("Petrolina", "Recife", "Petrolina"), c(3, 2, 1)),
    municipality_code = rep(c(2611101L, 2611606L, 2611101L), c(3, 2, 1)),
    registration_state = "PE",
    lon = x + 0.005, lat = y + 0.005, geometry_valid = TRUE,
    xmin = x, ymin = y, xmax = x + 0.01, ymax = y + 0.01
  )
  # The sixth property overlaps the first: a bigger square on the same corner.
  props$xmax[6] <- x[6] + 0.05
  props$ymax[6] <- y[6] + 0.05
  props$geometry <- blob::as_blob(c(
    lapply(1:5, function(i) square_wkb(x[i], y[i])),
    list(square_wkb(x[6], y[6], 0.05))
  ))
  con <- DBI::dbConnect(duckdb::duckdb())
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  dir.create(file.path(dir, "properties", "state=PE"), recursive = TRUE)
  dir.create(file.path(dir, "municipalities"))
  duckdb::duckdb_register(con, "props", props)
  f_props <- file.path(dir, "properties", "state=PE", "part-0.parquet")
  f_mun <- file.path(dir, "municipalities", "state=PE.parquet")
  DBI::dbExecute(con, sprintf(
    "COPY (SELECT * FROM props ORDER BY municipality_code) TO '%s' (FORMAT parquet)", f_props
  ))
  DBI::dbExecute(con, sprintf(
    "COPY (SELECT state, municipality_code, municipality, count(*) AS properties,
            count(*) FILTER (size_class = 'small') AS small_properties, sum(area_ha) AS area_ha,
            count(*) FILTER (status = 'active') AS active,
            count(*) FILTER (status = 'pending') AS pending,
            count(*) FILTER (status = 'suspended') AS suspended,
            count(*) FILTER (status = 'cancelled') AS cancelled,
            count(*) FILTER (NOT geometry_valid) AS invalid_geometries,
            min(xmin) AS xmin, min(ymin) AS ymin, max(xmax) AS xmax, max(ymax) AS ymax
          FROM props GROUP BY ALL) TO '%s' (FORMAT parquet)", f_mun
  ))
  dir.create(file.path(dir, "summary"))
  f_sum <- file.path(dir, "summary", "state=PE.parquet")
  DBI::dbExecute(con, sprintf(
    "COPY (SELECT state, status, size_class, property_type, condition,
            year(created_at)::INTEGER AS created_year, count(*) AS properties,
            sum(area_ha) AS area_ha
          FROM props GROUP BY ALL) TO '%s' (FORMAT parquet)", f_sum
  ))
  # Quality indicators: property 1 sits inside property 6; the cancelled one is left out.
  quality <- data.frame(
    property_code = props$property_code[c(1, 2, 3, 6, 4)],
    municipality_code = c(2611101L, 2611101L, 2611101L, 2611101L, 2611606L),
    overlap_count = c(1L, 0L, 0L, 1L, 0L),
    overlap_share = c(1, 0, 0, 0.04, 0),
    outside_share = c(0, 0, 0.6, 0, 0),
    # Property 2 sits on an indigenous land; 3, partly in a park; 6, wholly in an APA.
    indigenous_share = c(0, 0.8, 0, 0, 0),
    strict_protection_share = c(0, 0, 0.3, 0, 0),
    sustainable_use_share = c(0, 0, 0, 1, 0),
    indigenous_land = c(NA, "Terra Teste", NA, NA, NA),
    conservation_unit = c(NA, NA, "Parque Teste", "APA Teste", NA),
    conservation_category = c(NA, NA, "Parque", "APA", NA)
  )
  duckdb::duckdb_register(con, "quality", quality)
  dir.create(file.path(dir, "quality"))
  dir.create(file.path(dir, "quality-municipalities"))
  f_q <- file.path(dir, "quality", "state=PE.parquet")
  f_qm <- file.path(dir, "quality-municipalities", "state=PE.parquet")
  DBI::dbExecute(con, sprintf(
    "COPY (SELECT * FROM quality ORDER BY municipality_code, property_code) TO '%s' (FORMAT parquet)", f_q
  ))
  DBI::dbExecute(con, sprintf(
    "COPY (SELECT 'PE' AS state, q.municipality_code, count(*) AS properties,
            count(*) FILTER (overlap_share > 0.01) AS overlapping,
            count(*) FILTER (overlap_share > 0.5) AS overlapping_half,
            sum(p.area_ha * overlap_share) AS overlap_ha,
            count(*) FILTER (outside_share > 0.5) AS outside_half,
            sum(p.area_ha * outside_share) AS outside_ha,
            count(*) FILTER (indigenous_share > 0.01) AS indigenous,
            sum(p.area_ha * indigenous_share) AS indigenous_ha,
            count(*) FILTER (strict_protection_share > 0.01) AS strict_protection,
            sum(p.area_ha * strict_protection_share) AS strict_protection_ha,
            count(*) FILTER (sustainable_use_share > 0.01) AS sustainable_use,
            sum(p.area_ha * sustainable_use_share) AS sustainable_use_ha
          FROM quality q JOIN props p USING (property_code) GROUP BY ALL) TO '%s' (FORMAT parquet)", f_qm
  ))
  sha <- function(f) paste(unclass(openssl::sha256(file(f))), collapse = "")
  jsonlite::write_json(
    list(
      version = "2026-01-01",
      source = list(name = "teste"),
      states = list(PE = list(
        properties = 6L, municipalities = 2L,
        quality = list(invalid_geometries = 0L, null_geometries = 0L, registered_in_other_state = 0L)
      )),
      files = list(
        list(path = "properties/state=PE/part-0.parquet", sha256 = sha(f_props)),
        list(path = "municipalities/state=PE.parquet", sha256 = sha(f_mun)),
        list(path = "summary/state=PE.parquet", sha256 = sha(f_sum)),
        list(path = "quality/state=PE.parquet", sha256 = sha(f_q)),
        list(path = "quality-municipalities/state=PE.parquet", sha256 = sha(f_qm))
      )
    ),
    file.path(dir, "catalog.json"),
    auto_unbox = TRUE
  )
  jsonlite::write_json(
    list(list(column = "property_code", sicar_name = "cod_imovel", description = "Código")),
    file.path(dir, "dictionary.json"),
    auto_unbox = TRUE
  )
  withr::local_options(carbr.base_url = dir, carbr.quiet = TRUE, .local_envir = env)
  dir
}
