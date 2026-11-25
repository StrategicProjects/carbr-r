# Resumo pré-calculado

Contagem de imóveis e área declarada por qualquer combinação de UF,
situação, porte, tipo, etapa da análise e ano de criação do cadastro. Lê
tabelas pequenas, calculadas na publicação e guardadas em cache:
responde em segundos mesmo para o país inteiro, sem ler os imóveis.

## Usage

``` r
car_summary(by = "state", state = NULL)
```

## Arguments

- by:

  Dimensões do resumo, uma ou mais de `"state"`, `"status"`,
  `"size_class"`, `"property_type"`, `"condition"` e `"created_year"`.
  `NULL` devolve uma linha só, com o total.

- state:

  Sigla de uma ou mais UFs; `NULL` (padrão) traz todas as publicadas.

## Value

Um tibble com as colunas de `by`, `properties` (número de imóveis) e
`area_ha` (área declarada, em hectares). Zero linhas (com aviso) se a
publicação não responder.

## Examples

``` r
if (FALSE) { # interactive()
car_summary("state")
car_summary(c("size_class", "status"), state = "PE")
car_summary("created_year")
}
```
