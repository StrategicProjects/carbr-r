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

#' Remote files need DuckDB's `httpfs` extension, installed on first use
#' @noRd
car_need_httpfs <- function(con, error_call = rlang::caller_env()) {
  if (isTRUE(car_env$httpfs)) {
    return(invisible(TRUE))
  }
  ok <- tryCatch(
    {
      DBI::dbExecute(con, "LOAD httpfs")
      TRUE
    },
    error = function(cnd) {
      tryCatch(
        {
          DBI::dbExecute(con, "INSTALL httpfs")
          DBI::dbExecute(con, "LOAD httpfs")
          TRUE
        },
        error = function(cnd) FALSE
      )
    }
  )
  if (!ok) {
    cli::cli_abort(
      c(
        "DuckDB's {.pkg httpfs} extension could not be loaded.",
        "i" = "It is downloaded once from the DuckDB extension repository."
      ),
      class = "carbr_error_config",
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
