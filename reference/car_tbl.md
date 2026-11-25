# Tabela preguiçosa dos imóveis

Uma tabela `dplyr` sobre os arquivos publicados, para consultas que as
outras funções não cobrem. Nada é lido até o `collect()`; os verbos
[`filter()`](https://rdrr.io/r/stats/filter.html), `select()`, `count()`
e `summarise()` viram leitura parcial do arquivo remoto. A geometria vem
em WKB.

## Usage

``` r
car_tbl(state = NULL)
```

## Arguments

- state:

  Sigla de uma ou mais UFs; `NULL` (padrão) traz todas as publicadas.

## Value

Uma tabela preguiçosa (`tbl_lazy`), ou `NULL` (com aviso) se a
publicação não responder.

## Examples

``` r
if (FALSE) { # interactive()
car_tbl("PE") |>
  dplyr::count(status, size_class) |>
  dplyr::collect()
}
```
