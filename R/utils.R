#' Emit an informational message unless silenced
#' @noRd
car_inform <- function(..., .envir = parent.frame()) {
  quiet <- getOption("carbr.quiet", default = !rlang::is_interactive())
  if (!isTRUE(quiet)) {
    cli::cli_inform(..., .envir = .envir)
  }
  invisible(NULL)
}

#' `NULL` list elements become `NA`
#' @noRd
car_or_na <- function(x, na = NA) {
  if (is.null(x)) na else x
}

#' Lower case, no accents, single spaces: municipality names are matched
#' this way
#' @noRd
car_fold <- function(x) {
  x <- iconv(enc2utf8(as.character(x)), from = "UTF-8", to = "ASCII//TRANSLIT")
  x <- gsub("[^a-z0-9 ]", "", tolower(x))
  trimws(gsub(" +", " ", x))
}

#' State abbreviations, upper case and checked
#' @noRd
car_check_state <- function(state, available, error_call = rlang::caller_env()) {
  if (is.null(state)) {
    return(available)
  }
  state <- toupper(as.character(state))
  missing <- setdiff(state, available)
  if (length(missing) > 0) {
    cli::cli_abort(
      c(
        "State{?s} {.val {missing}} not in this publication.",
        "i" = "Available: {.val {available}}."
      ),
      class = "carbr_error_state",
      call = error_call
    )
  }
  state
}
