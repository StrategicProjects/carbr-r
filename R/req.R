#' Address of the publication
#'
#' A URL or a local folder holding the published tree. The default is the
#' public bucket; an S3-compatible mirror or a local copy can replace it.
#' @noRd
car_default_url <- "https://car.castlab.org/current"

#' @noRd
car_base_url <- function(error_call = rlang::caller_env()) {
  base <- getOption("carbr.base_url", Sys.getenv("CAR_URL", ""))
  if (!nzchar(base)) {
    base <- car_default_url
  }
  if (car_is_remote(base)) sub("/+$", "", base) else normalizePath(base, mustWork = FALSE)
}

#' @noRd
car_is_remote <- function(base) {
  grepl("^https?://", base)
}

#' Fetch a small file of the publication
#'
#' Network failures warn (per CRAN policy on internet resources) and return
#' `NULL` instead of erroring.
#' @returns A raw vector, or `NULL`.
#' @noRd
car_fetch <- function(path, error_call = rlang::caller_env()) {
  base <- car_base_url(error_call)
  if (!car_is_remote(base)) {
    file <- file.path(base, path)
    if (file.exists(file)) {
      return(readBin(file, "raw", file.size(file)))
    }
    cli::cli_warn(
      c("!" = "{.path {file}} does not exist.", "i" = "Returning {.code NULL}."),
      class = "carbr_error_http",
      call = error_call
    )
    return(NULL)
  }
  req <- httr2::request(base) |>
    httr2::req_url_path_append(utils::URLencode(path)) |>
    httr2::req_user_agent("carbr R package") |>
    httr2::req_timeout(getOption("carbr.timeout", 60)) |>
    httr2::req_retry(
      max_tries = getOption("carbr.max_tries", 3),
      backoff = function(i) 2^i,
      is_transient = function(resp) {
        httr2::resp_status(resp) %in% c(429L, 500L, 502L, 503L, 504L)
      }
    ) |>
    httr2::req_error(is_error = function(resp) FALSE)
  resp <- tryCatch(httr2::req_perform(req), error = function(cnd) cnd)
  if (!rlang::is_condition(resp) && httr2::resp_status(resp) == 200L) {
    return(httr2::resp_body_raw(resp))
  }
  reason <- if (rlang::is_condition(resp)) {
    conditionMessage(resp)
  } else {
    paste("HTTP", httr2::resp_status(resp))
  }
  cli::cli_warn(
    c(
      "!" = "The CAR publication could not be reached.",
      "i" = "Returning {.code NULL}. {reason}",
      "i" = "The service may be temporarily down; try again later."
    ),
    class = "carbr_error_http",
    call = error_call
  )
  NULL
}
