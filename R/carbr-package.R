#' @keywords internal
#' @section Opções do pacote:
#'
#' * `carbr.base_url`: endereço (ou pasta local) da publicação, também
#'   `CAR_URL`. O padrão é o bucket público; serve para apontar para um
#'   espelho ou para uma cópia local. A árvore tem `catalog.json`, `dictionary.json`,
#'   `municipalities/` e `properties/state=<UF>/`.
#' * `carbr.install_httpfs`: `TRUE` autoriza instalar a extensão `httpfs` do
#'   DuckDB sem perguntar; ver [car_install_httpfs()].
#' * `carbr.quiet`: silencia as mensagens informativas. Padrão `TRUE` em
#'   sessões não interativas.
#' * `carbr.cache_dir`: local do cache. Padrão
#'   `tools::R_user_dir("carbr", "cache")` (ou `CAR_CACHE_DIR`).
#' * `carbr.catalog_max_age`: segundos em que o catálogo em cache vale sem
#'   consultar o servidor. Padrão 6 horas.
#' * `carbr.max_tries`, `carbr.timeout`: tentativas (padrão 3, com espera
#'   exponencial) e tempo limite de cada requisição em segundos (padrão 60).
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang .data
## usethis namespace: end
NULL
