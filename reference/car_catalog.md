# O que está publicado

Uma linha por UF, com o número de imóveis e de municípios e os
indicadores de qualidade da carga. A versão da publicação fica em
`attr(x, "version")`, a origem em `attr(x, "source")` e a citação a usar
em `attr(x, "citation")`.

## Usage

``` r
car_catalog(refresh = FALSE)
```

## Arguments

- refresh:

  Se `TRUE`, ignora o catálogo em cache (válido por 6 horas).

## Value

Um tibble com as colunas `state`, `properties`, `municipalities`,
`invalid_geometries`, `null_geometries` e `registered_in_other_state`.
Zero linhas (com aviso) se a publicação não responder.

## Examples

``` r
if (FALSE) { # interactive()
car_catalog()
}
```
