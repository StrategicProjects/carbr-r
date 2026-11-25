car_env <- new.env(parent = emptyenv())

#' The package's DuckDB connection (in memory, created on first use)
#' @noRd
car_con <- function() {
  con <- car_env$con
  if (is.null(con) || !DBI::dbIsValid(con)) {
    con <- DBI::dbConnect(duckdb::duckdb())
    car_env$con <- con
    car_env$httpfs <- FALSE
  }
  con
}

#' Is DuckDB's `httpfs` extension installed?
#' @noRd
car_httpfs_installed <- function(con) {
  isTRUE(DBI::dbGetQuery(
    con, "SELECT installed FROM duckdb_extensions() WHERE extension_name = 'httpfs'"
  )$installed)
}

#' Instalar a extensão `httpfs` do DuckDB
#'
#' Para ler só os trechos necessários dos arquivos remotos, o `carbr` usa o
#' DuckDB com a extensão oficial `httpfs` (código aberto, licença MIT). O
#' DuckDB a baixa do seu próprio repositório de extensões para a pasta de
#' extensões dele, fora das pastas do `carbr`; por isso a instalação só é
#' feita com a sua confirmação.
#'
#' Em sessão interativa, o pacote pergunta na primeira leitura remota. Em
#' scripts, relatórios e automações, chame `car_install_httpfs()` uma vez
#' (a instalação fica guardada para as próximas sessões) ou defina
#' `options(carbr.install_httpfs = TRUE)`.
#'
#' @returns `TRUE`, invisível, se a extensão está instalada ao final.
#' @examplesIf interactive()
#' car_install_httpfs()
#' @export
car_install_httpfs <- function() {
  con <- car_con()
  if (car_httpfs_installed(con)) {
    car_inform(c("v" = "DuckDB's {.pkg httpfs} extension is already installed."))
    return(invisible(TRUE))
  }
  ok <- tryCatch(
    {
      DBI::dbExecute(con, "INSTALL httpfs")
      TRUE
    },
    error = function(cnd) FALSE
  )
  if (!ok) {
    cli::cli_abort(
      c(
        "DuckDB's {.pkg httpfs} extension could not be installed.",
        "i" = "It is downloaded from the DuckDB extension repository;
               check the internet connection and try again."
      ),
      class = "carbr_error_httpfs"
    )
  }
  car_inform(c("v" = "Installed DuckDB's {.pkg httpfs} extension."))
  invisible(TRUE)
}

#' Remote files need DuckDB's `httpfs` extension
#'
#' DuckDB loads the extension by itself once it is installed, but does not
#' install it, and neither does this package without the user's consent:
#' asked for in interactive sessions, given beforehand elsewhere (CRAN
#' policy on writing outside the package's own directories).
#' @noRd
car_need_httpfs <- function(con, error_call = rlang::caller_env()) {
  if (isTRUE(car_env$httpfs)) {
    return(invisible(TRUE))
  }
  if (!car_httpfs_installed(con)) {
    consent <- isTRUE(getOption("carbr.install_httpfs"))
    if (!consent && rlang::is_interactive()) {
      cli::cli_inform(c(
        "i" = "Reading remote files needs DuckDB's {.pkg httpfs} extension (open source, MIT).",
        " " = "DuckDB downloads it once from its extension repository into its own extension folder."
      ))
      consent <- isTRUE(utils::askYesNo("Install it now?", default = TRUE))
    }
    if (!consent) {
      cli::cli_abort(
        c(
          "DuckDB's {.pkg httpfs} extension is needed to read remote files and is not installed.",
          "i" = "Run {.run carbr::car_install_httpfs()} once, or set
                 {.code options(carbr.install_httpfs = TRUE)}."
        ),
        class = "carbr_error_httpfs",
        call = error_call
      )
    }
    car_install_httpfs()
  }
  ok <- tryCatch(
    {
      DBI::dbExecute(con, "LOAD httpfs")
      TRUE
    },
    error = function(cnd) FALSE
  )
  if (!ok) {
    cli::cli_abort(
      "DuckDB's {.pkg httpfs} extension could not be loaded.",
      class = "carbr_error_httpfs",
      call = error_call
    )
  }
  car_env$httpfs <- TRUE
  invisible(TRUE)
}

#' `read_parquet([...])` over the property files of the given states
#' @noRd
car_parquet_sql <- function(cat, state, error_call = rlang::caller_env()) {
  base <- car_base_url(error_call)
  paths <- vapply(cat$files, function(f) f$path, character(1))
  keep <- paths[sub("^properties/state=([A-Z]{2})/.*$", "\\1", paths) %in% state]
  if (car_is_remote(base)) {
    car_need_httpfs(car_con(), error_call)
    files <- paste0(base, "/", vapply(keep, utils::URLencode, character(1)))
  } else {
    files <- file.path(base, keep)
  }
  quoted <- as.character(DBI::dbQuoteString(car_con(), files))
  paste0("read_parquet([", paste(quoted, collapse = ", "), "])")
}

#' Run a query, turning a failed remote read into a warning and `NULL`
#' @noRd
car_collect <- function(query, error_call = rlang::caller_env()) {
  tryCatch(
    dplyr::collect(query),
    error = function(cnd) {
      cli::cli_warn(
        c(
          "!" = "The CAR publication could not be read.",
          "i" = "Returning an empty result. {conditionMessage(cnd)}"
        ),
        class = "carbr_error_http",
        call = error_call
      )
      NULL
    }
  )
}
