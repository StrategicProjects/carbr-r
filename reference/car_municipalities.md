# Resumo por município

Uma linha por município: imóveis, pequenos imóveis (até 4 módulos
fiscais), área declarada, contagem por situação, geometrias inválidas e
o retângulo envolvente dos imóveis.

## Usage

``` r
car_municipalities(state = NULL)
```

## Arguments

- state:

  Sigla de uma ou mais UFs; `NULL` (padrão) traz todas as publicadas.

## Value

Um tibble. Zero linhas (com aviso) se a publicação não responder.

## Examples

``` r
if (FALSE) { # interactive()
car_municipalities("PE")
}
```
