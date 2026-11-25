#' Citation of a publication version
#' @noRd
car_citation <- function(version) {
  paste0(
    "Servi\u00e7o Florestal Brasileiro. Sistema Nacional de Cadastro Ambiental ",
    "Rural (Sicar): im\u00f3veis rurais. Dados organizados pelo CastLab/UFPE ",
    "(pacote carbr), vers\u00e3o ", version, "."
  )
}

#' Como citar os dados
#'
#' A origem dos dados é o Sicar, do Serviço Florestal Brasileiro; a citação
#' credita a origem e identifica a versão lida.
#'
#' @returns O texto da citação, invisível; a função o imprime.
#' @examplesIf interactive()
#' car_cite()
#' @export
car_cite <- function() {
  cat <- car_catalog_json()
  if (is.null(cat)) {
    return(invisible(NA_character_))
  }
  txt <- car_citation(cat$version)
  cli::cli_text(txt)
  invisible(txt)
}
