#' Zero-row tibble with the published schema (graceful failure)
#' @noRd
car_empty_properties <- function() {
  tibble::tibble(
    property_code = character(), status_code = character(),
    status = character(), condition = character(),
    property_type_code = character(), property_type = character(),
    created_at = as.POSIXct(character(), tz = "UTC"), area_ha = double(),
    fiscal_modules = double(), size_class = character(),
    state = character(), municipality = character(),
    municipality_code = integer(), registration_state = character(),
    lon = double(), lat = double(), geometry_valid = logical(),
    xmin = double(), ymin = double(), xmax = double(), ymax = double(),
    geometry = list()
  )
}

#' Tibble, or `sf` when geometry was asked for and `sf` is installed
#' @noRd
car_finish <- function(out, geometry) {
  if (is.null(out)) {
    out <- car_empty_properties()
  }
  out <- tibble::as_tibble(out)
  if (!isTRUE(geometry)) {
    out$geometry <- NULL
    return(out)
  }
  if (!rlang::is_installed("sf")) {
    car_inform(c("i" = "Install {.pkg sf} to get the geometry as simple features; returning WKB."))
    return(out)
  }
  out$geometry <- sf::st_as_sfc(structure(as.list(out$geometry), class = "WKB"), crs = 4674)
  sf::st_as_sf(out, sf_column_name = "geometry")
}

#' O que está publicado
#'
#' Uma linha por UF, com o número de imóveis e de municípios e os
#' indicadores de qualidade da carga. A versão da publicação fica em
#' `attr(x, "version")`, a origem em `attr(x, "source")` e a citação a usar
#' em `attr(x, "citation")`.
#'
#' @param refresh Se `TRUE`, ignora o catálogo em cache (válido por 6 horas).
#' @returns Um tibble com as colunas `state`, `properties`,
#'   `municipalities`, `invalid_geometries`, `null_geometries` e
#'   `registered_in_other_state`. Zero linhas (com aviso) se a publicação
#'   não responder.
#' @examplesIf interactive()
#' car_catalog()
#' @export
car_catalog <- function(refresh = FALSE) {
  cat <- car_catalog_json(refresh = refresh)
  if (is.null(cat)) {
    return(tibble::tibble(
      state = character(), properties = integer(), municipalities = integer(),
      invalid_geometries = integer(), null_geometries = integer(),
      registered_in_other_state = integer()
    ))
  }
  int <- function(get) vapply(cat$states, function(s) as.integer(car_or_na(get(s))), integer(1), USE.NAMES = FALSE)
  out <- tibble::tibble(
    state = names(cat$states),
    properties = int(function(s) s$properties),
    municipalities = int(function(s) s$municipalities),
    invalid_geometries = int(function(s) s$quality$invalid_geometries),
    null_geometries = int(function(s) s$quality$null_geometries),
    registered_in_other_state = int(function(s) s$quality$registered_in_other_state)
  )
  attr(out, "version") <- cat$version
  attr(out, "source") <- cat$source
  attr(out, "citation") <- car_citation(cat$version)
  out
}

#' Dicionário de dados
#'
#' As colunas publicadas, o nome original de cada uma no Sicar e o que
#' significam.
#'
#' @returns Um tibble com as colunas `column`, `sicar_name` e `description`.
#' @examplesIf interactive()
#' car_dictionary()
#' @export
car_dictionary <- function() {
  raw <- car_fetch("dictionary.json")
  if (is.null(raw)) {
    return(tibble::tibble(column = character(), sicar_name = character(), description = character()))
  }
  dic <- jsonlite::fromJSON(rawToChar(raw), simplifyVector = FALSE)
  chr <- function(name) vapply(dic, function(d) as.character(car_or_na(d[[name]])), character(1))
  tibble::tibble(column = chr("column"), sicar_name = chr("sicar_name"), description = chr("description"))
}

#' Resumo por município
#'
#' Uma linha por município: imóveis, pequenos imóveis (até 4 módulos
#' fiscais), área declarada, contagem por situação, geometrias inválidas e
#' o retângulo envolvente dos imóveis.
#'
#' @param state Sigla de uma ou mais UFs; `NULL` (padrão) traz todas as
#'   publicadas.
#' @returns Um tibble. Zero linhas (com aviso) se a publicação não
#'   responder.
#' @examplesIf interactive()
#' car_municipalities("PE")
#' @export
car_municipalities <- function(state = NULL) {
  empty <- tibble::tibble(
    state = character(), municipality_code = integer(), municipality = character(),
    properties = integer(), small_properties = integer(), area_ha = double(),
    active = integer(), pending = integer(), suspended = integer(),
    cancelled = integer(), invalid_geometries = integer(),
    xmin = double(), ymin = double(), xmax = double(), ymax = double()
  )
  cat <- car_catalog_json()
  if (is.null(cat)) {
    return(empty)
  }
  state <- car_check_state(state, names(cat$states))
  files <- lapply(state, function(s) car_cached_file(cat, paste0("municipalities/state=", s, ".parquet")))
  if (any(vapply(files, is.null, logical(1)))) {
    return(empty)
  }
  con <- car_con()
  quoted <- as.character(DBI::dbQuoteString(con, unlist(files)))
  out <- DBI::dbGetQuery(con, paste0(
    "SELECT * FROM read_parquet([", paste(quoted, collapse = ", "), "]) ",
    "ORDER BY municipality_code"
  ))
  counts <- c("properties", "small_properties", "active", "pending", "suspended",
              "cancelled", "invalid_geometries")
  out[counts] <- lapply(out[counts], as.integer)
  tibble::as_tibble(out)
}

#' Resumo pré-calculado
#'
#' Contagem de imóveis e área declarada por qualquer combinação de UF,
#' situação, porte, tipo, etapa da análise e ano de criação do cadastro.
#' Lê tabelas pequenas, calculadas na publicação e guardadas em cache:
#' responde em segundos mesmo para o país inteiro, sem ler os imóveis.
#'
#' @param by Dimensões do resumo, uma ou mais de `"state"`, `"status"`,
#'   `"size_class"`, `"property_type"`, `"condition"` e `"created_year"`.
#'   `NULL` devolve uma linha só, com o total.
#' @inheritParams car_municipalities
#' @returns Um tibble com as colunas de `by`, `properties` (número de
#'   imóveis) e `area_ha` (área declarada, em hectares). Zero linhas (com
#'   aviso) se a publicação não responder.
#' @examplesIf interactive()
#' car_summary("state")
#' car_summary(c("size_class", "status"), state = "PE")
#' car_summary("created_year")
#' @export
car_summary <- function(by = "state", state = NULL) {
  dims <- c("state", "status", "size_class", "property_type", "condition", "created_year")
  by <- if (is.null(by)) character() else rlang::arg_match(by, dims, multiple = TRUE)
  empty <- tibble::tibble(
    state = character(), status = character(), size_class = character(),
    property_type = character(), condition = character(),
    created_year = integer(), properties = integer(), area_ha = double()
  )[c(by, "properties", "area_ha")]
  cat <- car_catalog_json()
  if (is.null(cat)) {
    return(empty)
  }
  state <- car_check_state(state, names(cat$states))
  paths <- paste0("summary/state=", state, ".parquet")
  listed <- function(cat) vapply(cat$files, function(f) f$path, character(1))
  if (!all(paths %in% listed(cat))) {
    # A catalogue cached before the summary was published.
    cat <- car_catalog_json(refresh = TRUE)
    if (is.null(cat)) {
      return(empty)
    }
  }
  files <- lapply(paths, function(p) car_cached_file(cat, p))
  if (any(vapply(files, is.null, logical(1)))) {
    return(empty)
  }
  con <- car_con()
  quoted <- as.character(DBI::dbQuoteString(con, unlist(files)))
  cols <- paste(c(by, "sum(properties)::INTEGER AS properties", "sum(area_ha) AS area_ha"), collapse = ", ")
  out <- DBI::dbGetQuery(con, paste0(
    "SELECT ", cols, " FROM read_parquet([", paste(quoted, collapse = ", "), "])",
    if (length(by) > 0) paste0(" GROUP BY ", paste(by, collapse = ", "), " ORDER BY ", paste(by, collapse = ", "))
  ))
  tibble::as_tibble(out)
}

#' Municipality codes from codes or names
#' @noRd
car_municipality_codes <- function(municipality, state, error_call = rlang::caller_env()) {
  if (is.numeric(municipality) || all(grepl("^[0-9]{7}$", municipality))) {
    return(as.integer(municipality))
  }
  known <- car_municipalities(state)
  hit <- match(car_fold(municipality), car_fold(known$municipality))
  if (anyNA(hit)) {
    unknown <- municipality[is.na(hit)]
    where <- paste(state, collapse = ", ")
    cli::cli_abort(
      c(
        "{cli::qty(length(unknown))}Municipalit{?y/ies} not found in {where}: {.val {unknown}}.",
        "i" = "See {.fn car_municipalities}, or pass the 7-digit IBGE code."
      ),
      class = "carbr_error_municipality",
      call = error_call
    )
  }
  # Names repeat across states: every match counts.
  known$municipality_code[car_fold(known$municipality) %in% car_fold(municipality)]
}

#' Tabela preguiçosa dos imóveis
#'
#' Uma tabela `dplyr` sobre os arquivos publicados, para consultas que as
#' outras funções não cobrem. Nada é lido até o `collect()`; os verbos
#' `filter()`, `select()`, `count()` e `summarise()` viram leitura parcial
#' do arquivo remoto. A geometria vem em WKB.
#'
#' @inheritParams car_municipalities
#' @returns Uma tabela preguiçosa (`tbl_lazy`), ou `NULL` (com aviso) se a
#'   publicação não responder.
#' @examplesIf interactive()
#' car_tbl("PE") |>
#'   dplyr::count(status, size_class) |>
#'   dplyr::collect()
#' @export
car_tbl <- function(state = NULL) {
  cat <- car_catalog_json()
  if (is.null(cat)) {
    return(invisible(NULL))
  }
  state <- car_check_state(state, names(cat$states))
  dplyr::tbl(car_con(), dbplyr::sql(paste("SELECT * FROM", car_parquet_sql(cat, state))))
}

#' Imóveis rurais declarados no CAR
#'
#' Os imóveis de uma UF, com filtros aplicados antes da leitura: só os
#' trechos do arquivo que atendem ao filtro são transferidos.
#'
#' @param state Sigla de uma ou mais UFs.
#' @param municipality Nomes ou códigos IBGE (7 dígitos) de municípios.
#' @param status Situação do cadastro: `"active"`, `"pending"`,
#'   `"suspended"`, `"cancelled"`.
#' @param size_class Porte: `"small"` (até 4 módulos fiscais), `"medium"`
#'   (acima de 4 até 15), `"large"`.
#' @param property_type Tipo: `"rural_property"`, `"settlement"`,
#'   `"traditional_community"`.
#' @param bbox Retângulo `c(xmin, ymin, xmax, ymax)` em graus (SIRGAS
#'   2000); traz os imóveis cujo retângulo envolvente o toca.
#' @param geometry Se `TRUE` (padrão), devolve o perímetro: um objeto `sf`
#'   quando o pacote `sf` está instalado, senão WKB. `FALSE` não transfere
#'   a geometria e é bem mais rápido.
#' @returns Um tibble ou objeto `sf`, uma linha por imóvel; as colunas
#'   estão em [car_dictionary()]. Zero linhas (com aviso) se a publicação
#'   não responder.
#' @examplesIf interactive()
#' car_properties("PE", municipality = "Petrolina", size_class = "large")
#' car_properties("PE", status = "pending", geometry = FALSE)
#' @export
car_properties <- function(state, municipality = NULL, status = NULL,
                           size_class = NULL, property_type = NULL,
                           bbox = NULL, geometry = TRUE) {
  if (!is.null(status)) {
    status <- rlang::arg_match(status, c("active", "pending", "suspended", "cancelled"), multiple = TRUE)
  }
  if (!is.null(size_class)) {
    size_class <- rlang::arg_match(size_class, c("small", "medium", "large"), multiple = TRUE)
  }
  if (!is.null(property_type)) {
    property_type <- rlang::arg_match(
      property_type, c("rural_property", "settlement", "traditional_community"),
      multiple = TRUE
    )
  }
  if (!is.null(bbox) && !(is.numeric(bbox) && length(bbox) == 4 && !anyNA(bbox))) {
    cli::cli_abort("{.arg bbox} must be {.code c(xmin, ymin, xmax, ymax)}.")
  }
  cat <- car_catalog_json()
  if (is.null(cat)) {
    return(car_finish(NULL, geometry))
  }
  state <- car_check_state(state, names(cat$states))
  q <- dplyr::tbl(car_con(), dbplyr::sql(paste("SELECT * FROM", car_parquet_sql(cat, state))))
  if (!is.null(municipality)) {
    codes <- car_municipality_codes(municipality, state)
    q <- dplyr::filter(q, .data$municipality_code %in% !!codes)
  }
  if (!is.null(status)) {
    q <- dplyr::filter(q, .data$status %in% !!status)
  }
  if (!is.null(size_class)) {
    q <- dplyr::filter(q, .data$size_class %in% !!size_class)
  }
  if (!is.null(property_type)) {
    q <- dplyr::filter(q, .data$property_type %in% !!property_type)
  }
  if (!is.null(bbox)) {
    q <- dplyr::filter(
      q,
      .data$xmax >= !!bbox[[1]], .data$ymax >= !!bbox[[2]],
      .data$xmin <= !!bbox[[3]], .data$ymin <= !!bbox[[4]]
    )
  }
  if (!isTRUE(geometry)) {
    q <- dplyr::select(q, -"geometry")
  }
  car_finish(car_collect(q), geometry)
}

#' Um imóvel pelo código
#'
#' @param code Um ou mais códigos de imóvel no CAR
#'   (`UF-0000000-identificador`).
#' @inheritParams car_properties
#' @returns Um tibble ou objeto `sf` com uma linha por código encontrado.
#' @examplesIf interactive()
#' car_property("PE-2611101-588BC484570D440484F527F07DF5AFFA")
#' @export
car_property <- function(code, geometry = TRUE) {
  code <- toupper(trimws(as.character(code)))
  bad <- code[!grepl("^[A-Z]{2}-[0-9]{7}-[0-9A-F]{32}$", code)]
  if (length(bad) > 0) {
    cli::cli_abort(
      c(
        "Not {cli::qty(length(bad))}{?a CAR property code/CAR property codes}: {.val {bad}}.",
        "i" = "Expected {.val UF-0000000-} followed by 32 hexadecimal digits."
      ),
      class = "carbr_error_code"
    )
  }
  cat <- car_catalog_json()
  if (is.null(cat)) {
    return(car_finish(NULL, geometry))
  }
  available <- names(cat$states)
  all <- dplyr::tbl(car_con(), dbplyr::sql(paste("SELECT * FROM", car_parquet_sql(cat, available))))
  if (!isTRUE(geometry)) {
    all <- dplyr::select(all, -"geometry")
  }
  # The code carries the municipality: that filter reads a few row groups.
  codes_mun <- as.integer(substr(code, 4, 10))
  out <- car_collect(dplyr::filter(
    all, .data$municipality_code %in% !!codes_mun, .data$property_code %in% !!code
  ))
  if (is.null(out)) {
    return(car_finish(NULL, geometry))
  }
  # A few properties sit in another municipality or state than the code says.
  left <- setdiff(code, out$property_code)
  if (length(left) > 0) {
    more <- car_collect(dplyr::filter(all, .data$property_code %in% !!left))
    if (!is.null(more)) {
      out <- rbind(out, more)
    }
  }
  car_finish(out, geometry)
}

#' Imóveis que contêm um ponto
#'
#' Responde "que imóveis estão declarados aqui?". O filtro pelo retângulo
#' envolvente é feito na leitura remota e o teste exato, com o pacote `sf`.
#' Sobreposições entre imóveis são comuns: o resultado pode ter mais de uma
#' linha.
#'
#' @param lon,lat Longitude e latitude do ponto, em graus (SIRGAS 2000).
#' @param state Siglas das UFs onde procurar; `NULL` (padrão) procura em
#'   todas as publicadas.
#' @inheritParams car_properties
#' @returns Um tibble ou objeto `sf`; zero linhas se nenhum imóvel contém o
#'   ponto.
#' @examplesIf interactive()
#' car_at(lon = -40.5, lat = -9.2)
#' @export
car_at <- function(lon, lat, state = NULL, geometry = TRUE) {
  if (!(is.numeric(lon) && is.numeric(lat) && length(lon) == 1 && length(lat) == 1 &&
    !is.na(lon) && !is.na(lat))) {
    cli::cli_abort("{.arg lon} and {.arg lat} must be single numbers.")
  }
  rlang::check_installed("sf", reason = "to test which properties contain the point.")
  cat <- car_catalog_json()
  if (is.null(cat)) {
    return(car_finish(NULL, geometry))
  }
  state <- car_check_state(state, names(cat$states))
  q <- dplyr::tbl(car_con(), dbplyr::sql(paste("SELECT * FROM", car_parquet_sql(cat, state))))
  out <- car_collect(dplyr::filter(
    q, .data$xmin <= !!lon, .data$xmax >= !!lon, .data$ymin <= !!lat, .data$ymax >= !!lat
  ))
  out <- car_finish(out, geometry = TRUE)
  if (nrow(out) > 0) {
    # Planar test: declared perimeters are not always valid on the sphere.
    s2 <- suppressMessages(sf::sf_use_s2(FALSE))
    on.exit(suppressMessages(sf::sf_use_s2(s2)))
    point <- sf::st_sfc(sf::st_point(c(lon, lat)), crs = 4674)
    hit <- suppressMessages(lengths(sf::st_intersects(out, point)) > 0)
    out <- out[hit, ]
  }
  if (!isTRUE(geometry)) {
    out <- tibble::as_tibble(sf::st_drop_geometry(out))
  }
  out
}
