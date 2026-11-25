#' Pasta de cache do carbr
#'
#' O catálogo, o dicionário e o resumo municipal ficam em cache em disco,
#' uma pasta por versão do catálogo. Os imóveis não são copiados: cada
#' consulta lê do arquivo remoto só os trechos de que precisa.
#' `car_cache_clear()` apaga o cache.
#'
#' @returns O caminho da pasta de cache (invisível em `car_cache_clear()`).
#' @examples
#' car_cache_dir()
#' @export
car_cache_dir <- function() {
  getOption(
    "carbr.cache_dir",
    Sys.getenv("CAR_CACHE_DIR", tools::R_user_dir("carbr", "cache"))
  )
}

#' @rdname car_cache_dir
#' @export
car_cache_clear <- function() {
  dir <- car_cache_dir()
  if (dir.exists(dir)) {
    unlink(dir, recursive = TRUE)
    car_inform(c("v" = "Cleared carbr cache at {.path {dir}}."))
  } else {
    car_inform(c("i" = "No carbr cache found at {.path {dir}}."))
  }
  invisible(dir)
}

#' The published catalogue, from the disk cache when recent enough
#'
#' A local publication is read directly. A stale cached catalogue is used
#' when the server cannot be reached.
#' @returns The parsed catalogue (a list), or `NULL`.
#' @noRd
car_catalog_json <- function(refresh = FALSE, error_call = rlang::caller_env()) {
  base <- car_base_url(error_call)
  parse <- function(raw) {
    cat <- jsonlite::fromJSON(rawToChar(raw), simplifyVector = FALSE)
    if (is.null(cat$version) || is.null(cat$files)) {
      cli::cli_abort(
        "Unexpected catalogue format (no {.field version}/{.field files}).",
        class = "carbr_error_catalog",
        call = error_call
      )
    }
    cat
  }
  if (!car_is_remote(base)) {
    raw <- car_fetch("catalog.json", error_call = error_call)
    return(if (is.null(raw)) NULL else parse(raw))
  }
  path <- file.path(car_cache_dir(), "catalog.json")
  age <- if (file.exists(path)) {
    as.numeric(difftime(Sys.time(), file.mtime(path), units = "secs"))
  } else {
    Inf
  }
  if (!isTRUE(refresh) && age < getOption("carbr.catalog_max_age", 6 * 3600)) {
    return(parse(readBin(path, "raw", file.size(path))))
  }
  raw <- car_fetch("catalog.json", error_call = error_call)
  if (is.null(raw)) {
    if (file.exists(path)) {
      car_inform(c("i" = "Using the cached catalogue."))
      return(parse(readBin(path, "raw", file.size(path))))
    }
    return(NULL)
  }
  cat <- parse(raw)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeBin(raw, path)
  cat
}

#' Path to a verified local copy of a small catalogue file
#' @returns The local path, or `NULL` when the file could not be fetched.
#' @noRd
car_cached_file <- function(cat, path, error_call = rlang::caller_env()) {
  entry <- Filter(function(f) identical(f$path, path), cat$files)
  if (length(entry) == 0) {
    cli::cli_abort(
      "{.path {path}} is not in the catalogue.",
      class = "carbr_error_catalog",
      call = error_call
    )
  }
  sha256 <- entry[[1]]$sha256
  base <- car_base_url(error_call)
  if (!car_is_remote(base)) {
    return(file.path(base, path))
  }
  dest <- file.path(car_cache_dir(), cat$version, path)
  if (file.exists(dest) && car_sha256(dest) == sha256) {
    return(dest)
  }
  raw <- car_fetch(path, error_call = error_call)
  if (is.null(raw)) {
    return(NULL)
  }
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(dest, ".tmp")
  writeBin(raw, tmp)
  if (car_sha256(tmp) != sha256) {
    unlink(tmp)
    cli::cli_abort(
      c(
        "{.path {path}} does not match the SHA-256 in the catalogue.",
        "i" = "The publication may be in progress; try again in a few minutes."
      ),
      class = "carbr_error_integrity",
      call = error_call
    )
  }
  file.rename(tmp, dest)
  # Files of other catalogue versions are superseded.
  old <- setdiff(list.dirs(car_cache_dir(), recursive = FALSE, full.names = FALSE), cat$version)
  unlink(file.path(car_cache_dir(), old), recursive = TRUE)
  dest
}

#' SHA-256 of a file
#' @noRd
car_sha256 <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con))
  paste(unclass(openssl::sha256(con)), collapse = "")
}
