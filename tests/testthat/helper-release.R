# A tiny publication on disk: six square properties in two municipalities,
# written with the same layout and columns as the real one.

square_wkb <- function(x, y, side = 0.01) {
  ring <- rbind(c(x, y), c(x + side, y), c(x + side, y + side), c(x, y + side), c(x, y))
  sf::st_as_binary(sf::st_multipolygon(list(list(ring))))
}

release_teste <- function(env = parent.frame()) {
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
        list(path = "summary/state=PE.parquet", sha256 = sha(f_sum))
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
