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

#' Etapa da análise a partir da situação informada pelo Sicar
#' @noRd
car_stage <- function(condition) {
  dplyr::case_when(
    is.na(condition) ~ NA_character_,
    startsWith(condition, "Cancelado") ~ "cancelled",
    condition == "Aguardando an\u00e1lise" ~ "waiting",
    condition == "Em an\u00e1lise" ~ "analysing",
    grepl("aguardando atendimento a notifica\u00e7\u00e3o", condition, fixed = TRUE) ~ "notified",
    grepl("ap\u00f3s revis\u00e3o", condition, fixed = TRUE) ~ "answered",
    TRUE ~ "done"
  )
}

#' Verificar vários imóveis de uma vez
#'
#' Para uma lista de códigos, diz o que consta de cada um na camada pública
#' do CAR e resume em um resultado: a triagem que antecede, por exemplo, a
#' análise de um pedido de crédito rural. Os códigos são agrupados por UF e
#' município, de modo que uma lista grande lê poucos trechos de cada arquivo.
#'
#' O resultado (`check`) é uma classificação do pacote, não uma regra
#' oficial:
#'
#' * `"ok"`: cadastro ativo, sem notificação pendente;
#' * `"attention"`: cadastro pendente, analisado com notificação ainda sem
#'   resposta do declarante, com mais de 1% da área sobre terra indígena ou
#'   unidade de conservação de proteção integral, ou com embargo ambiental
#'   ativo do Ibama;
#' * `"blocked"`: cadastro cancelado ou suspenso;
#' * `"not_found"`: código que não está na publicação (pode ter sido
#'   cadastrado depois da última atualização);
#' * `"invalid"`: texto que não tem o formato de um código do CAR.
#'
#' A sobreposição com terras indígenas (Funai) e unidades de conservação
#' (CNUC/MMA) é calculada na publicação, pelos perímetros declarados. Estar
#' em unidade de uso sustentável é informado na nota, mas não muda o
#' resultado: áreas de proteção ambiental e reservas particulares admitem
#' imóveis privados. Os embargos são os do Ibama (dados abertos, termos não
#' cancelados e sem desembargo), localizados pelo polígono ou pelo ponto do
#' termo; não entram embargos estaduais nem do ICMBio. A verificação não
#' cobre os demais impedimentos do crédito rural (territórios quilombolas,
#' florestas públicas não destinadas, supressão de vegetação, trabalho
#' análogo à escravidão) e não substitui a consulta oficial ao Sicar.
#'
#' @param code Códigos de imóvel no CAR (`UF-0000000-identificador`).
#' @returns Um tibble com uma linha por código, na ordem dada: `property_code`,
#'   `check`, `note` (o motivo, em português), `stage` (a etapa da análise:
#'   `"waiting"`, `"analysing"`, `"notified"`, `"answered"`, `"done"` ou
#'   `"cancelled"`), `status`, `condition`, `property_type`, `size_class`,
#'   `area_ha`, `fiscal_modules`, `state`, `municipality`, `created_at` e,
#'   para os imóveis não cancelados, `indigenous_share`,
#'   `strict_protection_share`, `sustainable_use_share` (parcelas da área, de
#'   0 a 1), `protected_area` (os nomes das áreas sobrepostas),
#'   `embargo_count` e `embargo_share`.
#' @examplesIf interactive()
#' car_check(c(
#'   "PE-2611101-588BC484570D440484F527F07DF5AFFA",
#'   "PE-2611101-00000000000000000000000000000000"
#' ))
#' @export
car_check <- function(code) {
  code <- unique(toupper(trimws(as.character(code))))
  code <- code[!is.na(code) & nzchar(code)]
  valid <- grepl("^[A-Z]{2}-[0-9]{7}-[0-9A-F]{32}$", code)
  columns <- c(
    "property_code", "status", "condition", "property_type", "size_class",
    "area_ha", "fiscal_modules", "state", "municipality", "created_at"
  )
  found <- car_empty_properties()[columns]
  towns_found <- integer()
  cat <- car_catalog_json()
  if (!is.null(cat) && any(valid)) {
    for (uf in intersect(unique(substr(code[valid], 1, 2)), names(cat$states))) {
      wanted <- code[valid & substr(code, 1, 2) == uf]
      tbl <- dplyr::tbl(car_con(), dbplyr::sql(paste("SELECT * FROM", car_parquet_sql(cat, uf)))) |>
        dplyr::select(dplyr::all_of(c(columns, "municipality_code")))
      # The code carries the municipality: that filter reads a few row groups.
      towns <- unique(as.integer(substr(wanted, 4, 10)))
      part <- car_collect(dplyr::filter(
        tbl, .data$municipality_code %in% !!towns, .data$property_code %in% !!wanted
      ))
      left <- setdiff(wanted, part$property_code)
      if (!is.null(part) && length(left) > 0) {
        # A few properties sit in another municipality than the code says.
        more <- car_collect(dplyr::filter(tbl, .data$property_code %in% !!left))
        if (!is.null(more)) part <- rbind(part, more)
      }
      if (!is.null(part)) {
        found <- rbind(found, tibble::as_tibble(part)[columns])
        towns_found <- c(towns_found, stats::setNames(part$municipality_code, part$property_code))
      }
    }
  }
  out <- dplyr::left_join(tibble::tibble(property_code = code), found, by = "property_code")
  out <- dplyr::left_join(out, car_check_quality(towns_found), by = "property_code")
  missing <- is.na(out$state)
  out$stage <- car_stage(out$condition)
  out$check <- dplyr::case_when(
    !valid ~ "invalid",
    missing ~ "not_found",
    out$status %in% c("cancelled", "suspended") | out$stage == "cancelled" ~ "blocked",
    out$status == "pending" | out$stage == "notified" ~ "attention",
    is.na(out$status) ~ "attention",
    TRUE ~ "ok"
  )
  out$note <- dplyr::case_when(
    out$check == "invalid" ~ "Texto fora do formato de um c\u00f3digo do CAR.",
    out$check == "not_found" ~ "C\u00f3digo n\u00e3o encontrado nesta publica\u00e7\u00e3o.",
    out$status == "cancelled" | out$stage == "cancelled" ~ "Cadastro cancelado.",
    out$status == "suspended" ~ "Cadastro suspenso.",
    out$stage == "notified" ~ "Analisado, com notifica\u00e7\u00e3o sem resposta do declarante.",
    out$status == "pending" ~ "Cadastro pendente.",
    is.na(out$status) ~ "Situa\u00e7\u00e3o n\u00e3o reconhecida.",
    TRUE ~ "Cadastro ativo, sem notifica\u00e7\u00e3o pendente."
  )
  # Indigenous lands and conservation units: under 1% of the area is boundary noise.
  share <- function(x) ifelse(is.na(x), 0, x)
  ti <- share(out$indigenous_share) >= 0.01
  strict <- share(out$strict_protection_share) >= 0.01
  sustainable <- !strict & share(out$sustainable_use_share) >= 0.01
  extra <- paste0(
    ifelse(ti, paste0(
      " Sobrep\u00f5e terra ind\u00edgena (", out$indigenous_land, ") em ", car_percent(out$indigenous_share), "."
    ), ""),
    ifelse(strict, paste0(
      " Sobrep\u00f5e unidade de conserva\u00e7\u00e3o de prote\u00e7\u00e3o integral (", out$conservation_unit, ") em ",
      car_percent(out$strict_protection_share), "."
    ), ""),
    ifelse(sustainable & out$check != "blocked", paste0(
      " Fica em unidade de conserva\u00e7\u00e3o de uso sustent\u00e1vel (", out$conservation_category, ": ",
      out$conservation_unit, "), em ", car_percent(out$sustainable_use_share), "."
    ), "")
  )
  embargoes <- ifelse(is.na(out$embargo_count), 0L, out$embargo_count)
  covered <- share(out$embargo_share)
  extra <- paste0(extra, ifelse(embargoes > 0, paste0(
    ifelse(embargoes == 1, " H\u00e1 1 embargo ambiental ativo do Ibama",
      paste0(" H\u00e1 ", embargoes, " embargos ambientais ativos do Ibama")),
    ifelse(covered >= 0.01, paste0(", sobre ", car_percent(covered), "."), " no im\u00f3vel.")
  ), ""))
  alert <- (ti | strict | embargoes > 0) & out$check == "ok"
  out$note <- trimws(paste0(ifelse(alert, "", out$note), extra))
  out$check[alert] <- "attention"
  out$protected_area <- mapply(function(a, b, c, d) {
    names <- c(if (a) b, if (c) d)
    if (length(names) == 0) NA_character_ else paste(names, collapse = "; ")
  }, ti, out$indigenous_land, strict | sustainable, out$conservation_unit, USE.NAMES = FALSE)
  out[c(
    "property_code", "check", "note", "stage", setdiff(columns, "property_code"),
    "indigenous_share", "strict_protection_share", "sustainable_use_share", "protected_area",
    "embargo_count", "embargo_share"
  )]
}

#' "toda a area" or "NN% da area"
#' @noRd
car_percent <- function(share) {
  ifelse(!is.na(share) & share >= 0.995, "toda a \u00e1rea", paste0(pmax(1, round(100 * share)), "% da \u00e1rea"))
}

#' Overlap with protected areas for the properties found by [car_check()]
#' @param towns Municipality codes named by property code.
#' @noRd
car_check_quality <- function(towns) {
  columns <- c(
    "property_code", "indigenous_share", "strict_protection_share", "sustainable_use_share",
    "indigenous_land", "conservation_unit", "conservation_category", "embargo_count", "embargo_share"
  )
  out <- car_empty_quality()[columns]
  for (uf in unique(substr(names(towns), 1, 2))) {
    here <- towns[substr(names(towns), 1, 2) == uf]
    part <- suppressWarnings(car_quality(uf, municipality = unique(unname(here))))
    out <- rbind(out, part[part$property_code %in% names(here), columns])
  }
  out
}

#' Zero-row tibble with the columns of [car_quality()]
#' @noRd
car_empty_quality <- function() {
  tibble::tibble(
    property_code = character(), municipality_code = integer(),
    overlap_count = integer(), overlap_share = double(), outside_share = double(),
    indigenous_share = double(), strict_protection_share = double(), sustainable_use_share = double(),
    indigenous_land = character(), conservation_unit = character(), conservation_category = character(),
    embargo_count = integer(), embargo_share = double()
  )
}

#' Add the columns of `empty` that `out` lacks (as `NA`) and put them in order
#' @noRd
car_like <- function(out, empty) {
  for (name in setdiff(names(empty), names(out))) out[[name]] <- rep(empty[[name]][NA_integer_], nrow(out))
  tibble::as_tibble(out)[names(empty)]
}

#' Indicadores de qualidade do cadastro
#'
#' Sinais calculados na publicação para cada imóvel não cancelado:
#'
#' * `overlap_count` e `overlap_share`: com quantos outros imóveis do estado
#'   ele divide área, e que parcela da área dele está sobreposta (a soma das
#'   interseções com cada vizinho, limitada a 1);
#' * `outside_share`: que parcela da área fica fora do município declarado,
#'   pela malha municipal do IBGE;
#' * `indigenous_share`: que parcela fica dentro de terras indígenas (Funai,
#'   todas as fases do processo), com o nome da principal em
#'   `indigenous_land`;
#' * `strict_protection_share` e `sustainable_use_share`: que parcela fica
#'   dentro de unidades de conservação de proteção integral e de uso
#'   sustentável (CNUC/MMA), com o nome e a categoria da principal em
#'   `conservation_unit` e `conservation_category` (a de proteção integral,
#'   se houver);
#' * `embargo_count` e `embargo_share`: quantos embargos ambientais ativos do
#'   Ibama alcançam o imóvel e que parcela da área está embargada (só os
#'   termos que têm o polígono da área; os demais contam pelo ponto de
#'   referência).
#'
#' `car_quality()` traz os indicadores por imóvel; `car_quality_summary()`,
#' o resumo por município: imóveis não cancelados (`properties`), quantos
#' têm sobreposição acima de 1% (`overlapping`) e de 50% da área
#' (`overlapping_half`), os hectares sobrepostos (`overlap_ha`, somando os
#' dois lados de cada par), e quantos imóveis (`outside_half`) e hectares
#' (`outside_ha`) ficam fora do município declarado; e, para terras
#' indígenas (`indigenous`), unidades de proteção integral
#' (`strict_protection`) e de uso sustentável (`sustainable_use`), quantos
#' imóveis têm mais de 1% da área dentro delas e quantos hectares (`*_ha`);
#' e quantos imóveis têm embargo ativo do Ibama (`embargoed`) e os hectares
#' embargados (`embargo_ha`).
#'
#' Sobreposição entre imóveis não é sinônimo de disputa: inclui imóvel
#' declarado duas vezes e lote dentro de assentamento; a comparação é só
#' entre imóveis do mesmo estado. Estar em unidade de uso sustentável também
#' não é irregularidade: áreas de proteção ambiental (APA) e reservas
#' particulares (RPPN) admitem imóveis privados. As edições das camadas
#' estão em `source$protected_areas` no catálogo.
#'
#' @param state Sigla de uma ou mais UFs. Em `car_quality_summary()`, `NULL`
#'   (padrão) traz todas as publicadas.
#' @param municipality Nomes ou códigos IBGE (7 dígitos) de municípios; lê
#'   só os trechos deles.
#' @returns Um tibble. `car_quality()`: `property_code`, `municipality_code`
#'   e os indicadores acima; junte a [car_properties()] por `property_code`.
#'   Zero linhas (com aviso) se a publicação não responder ou não trouxer os
#'   indicadores; as colunas de terras indígenas e unidades de conservação
#'   vêm vazias se a publicação ainda não as traz.
#' @examplesIf interactive()
#' car_quality("PE", municipality = "Petrolina")
#' car_quality_summary("PE")
#' @export
car_quality <- function(state, municipality = NULL) {
  empty <- car_empty_quality()
  cat <- car_catalog_json()
  if (is.null(cat)) {
    return(empty)
  }
  state <- car_check_state(state, names(cat$states))
  sql <- car_data_sql(cat, "quality", state)
  if (is.null(sql)) {
    cat <- car_catalog_json(refresh = TRUE)
    sql <- if (is.null(cat)) NULL else car_data_sql(cat, "quality", state)
  }
  if (is.null(sql)) {
    cli::cli_warn(
      c("!" = "This publication has no quality indicators.", "i" = "Returning an empty result."),
      class = "carbr_error_http"
    )
    return(empty)
  }
  q <- dplyr::tbl(car_con(), dbplyr::sql(paste("SELECT * FROM", sql)))
  if (!is.null(municipality)) {
    codes <- car_municipality_codes(municipality, state)
    q <- dplyr::filter(q, .data$municipality_code %in% !!codes)
  }
  out <- car_collect(q)
  if (is.null(out)) {
    return(empty)
  }
  car_like(out, empty)
}

#' @rdname car_quality
#' @export
car_quality_summary <- function(state = NULL) {
  empty <- tibble::tibble(
    state = character(), municipality_code = integer(), municipality = character(),
    properties = integer(), overlapping = integer(), overlapping_half = integer(),
    overlap_ha = double(), outside_half = integer(), outside_ha = double(),
    indigenous = integer(), indigenous_ha = double(),
    strict_protection = integer(), strict_protection_ha = double(),
    sustainable_use = integer(), sustainable_use_ha = double(),
    embargoed = integer(), embargo_ha = double()
  )
  cat <- car_catalog_json()
  if (is.null(cat)) {
    return(empty)
  }
  state <- car_check_state(state, names(cat$states))
  paths <- paste0("quality-municipalities/state=", state, ".parquet")
  listed <- function(cat) vapply(cat$files, function(f) f$path, character(1))
  if (!all(paths %in% listed(cat))) {
    cat <- car_catalog_json(refresh = TRUE)
    if (is.null(cat) || !all(paths %in% listed(cat))) {
      cli::cli_warn(
        c("!" = "This publication has no quality indicators.", "i" = "Returning an empty result."),
        class = "carbr_error_http"
      )
      return(empty)
    }
  }
  files <- lapply(paths, function(p) car_cached_file(cat, p))
  if (any(vapply(files, is.null, logical(1)))) {
    return(empty)
  }
  con <- car_con()
  quoted <- as.character(DBI::dbQuoteString(con, unlist(files)))
  out <- DBI::dbGetQuery(con, paste0(
    "SELECT * FROM read_parquet([", paste(quoted, collapse = ", "),
    "], union_by_name = true) ORDER BY municipality_code"
  ))
  counts <- intersect(names(out), names(empty)[vapply(empty, is.integer, logical(1))])
  out[counts] <- lapply(out[counts], as.integer)
  names <- car_municipalities(state)[c("municipality_code", "municipality")]
  car_like(dplyr::left_join(tibble::as_tibble(out), names, by = "municipality_code"), empty)
}

#' Tipologia dos municípios
#'
#' Cada município entra num de cinco grupos, pelo perfil do seu cadastro: o
#' porte dos imóveis, em que etapa a análise está e quanto os cadastros se
#' sobrepõem. Os grupos são achados por agrupamento (k-médias) sobre sete
#' indicadores e ficam fixos de uma atualização para a outra, de modo que dá
#' para acompanhar um município mudando de grupo. Municípios com menos de 30
#' imóveis não cancelados ficam em `"few"`.
#'
#' Os indicadores, todos sobre os imóveis não cancelados do município:
#'
#' * `small_share`: parcela de imóveis pequenos (até 4 módulos fiscais);
#' * `large_area_share`: parcela da área declarada que está em imóveis
#'   grandes;
#' * `waiting_share`, `notified_share` e `analysed_share`: parcela aguardando
#'   análise, notificada sem resposta e já analisada ou em análise;
#' * `overlap_share`: parcela com mais da metade da área sobreposta a outros
#'   cadastros;
#' * `coverage`: área declarada dividida pela área do município (limitada
#'   a 2).
#'
#' @param state Sigla de uma ou mais UFs; `NULL` (padrão) traz o país inteiro.
#' @returns `car_typology()`: um tibble com uma linha por município: `state`,
#'   `municipality_code`, `municipality`, `typology` (o código do grupo),
#'   `typology_label` (o nome), `properties` e os sete indicadores.
#'   `car_typology_groups()`: um tibble com uma linha por grupo: `typology`,
#'   `typology_label`, `description` (o que o distingue), `municipalities` e
#'   `properties` (quantos municípios e imóveis estão nele na publicação
#'   atual).
#' @examplesIf interactive()
#' car_typology("PE")
#' car_typology_groups()
#' @export
car_typology <- function(state = NULL) {
  empty <- tibble::tibble(
    state = character(), municipality_code = integer(), municipality = character(),
    typology = character(), typology_label = character(), properties = integer(),
    small_share = double(), large_area_share = double(), waiting_share = double(),
    notified_share = double(), analysed_share = double(), overlap_share = double(),
    coverage = double()
  )
  cat <- car_catalog_json()
  if (is.null(cat)) {
    return(empty)
  }
  state <- car_check_state(state, names(cat$states))
  path <- "typology/municipalities.parquet"
  listed <- function(cat) path %in% vapply(cat$files, function(f) f$path, character(1))
  if (!listed(cat)) {
    cat <- car_catalog_json(refresh = TRUE)
    if (is.null(cat) || !listed(cat)) {
      cli::cli_warn(
        c("!" = "This publication has no typology.", "i" = "Returning an empty result."),
        class = "carbr_error_http"
      )
      return(empty)
    }
  }
  file <- car_cached_file(cat, path)
  if (is.null(file)) {
    return(empty)
  }
  con <- car_con()
  out <- DBI::dbGetQuery(con, paste0(
    "SELECT * FROM read_parquet(", DBI::dbQuoteString(con, file), ") ORDER BY municipality_code"
  ))
  out$properties <- as.integer(out$properties)
  out <- car_like(out, empty)
  out[out$state %in% state, ]
}

#' @rdname car_typology
#' @export
car_typology_groups <- function() {
  empty <- tibble::tibble(
    typology = character(), typology_label = character(), description = character(),
    municipalities = integer(), properties = integer()
  )
  cat <- car_catalog_json()
  groups <- cat$typology$groups
  if (is.null(groups) || length(groups) == 0) {
    return(empty)
  }
  tibble::tibble(
    typology = vapply(groups, function(g) g$code, character(1)),
    typology_label = vapply(groups, function(g) g$label, character(1)),
    description = vapply(groups, function(g) g$description, character(1)),
    municipalities = vapply(groups, function(g) as.integer(g$municipalities), integer(1)),
    properties = vapply(groups, function(g) as.integer(g$properties), integer(1))
  )
}
