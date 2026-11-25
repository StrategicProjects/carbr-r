# Imóveis que contêm um ponto

Responde "que imóveis estão declarados aqui?". O filtro pelo retângulo
envolvente é feito na leitura remota e o teste exato, com o pacote `sf`.
Sobreposições entre imóveis são comuns: o resultado pode ter mais de uma
linha.

## Usage

``` r
car_at(lon, lat, state = NULL, geometry = TRUE)
```

## Arguments

- lon, lat:

  Longitude e latitude do ponto, em graus (SIRGAS 2000).

- state:

  Siglas das UFs onde procurar; `NULL` (padrão) procura em todas as
  publicadas.

- geometry:

  Se `TRUE` (padrão), devolve o perímetro: um objeto `sf` quando o
  pacote `sf` está instalado, senão WKB. `FALSE` não transfere a
  geometria e é bem mais rápido.

## Value

Um tibble ou objeto `sf`; zero linhas se nenhum imóvel contém o ponto.

## Examples

``` r
if (FALSE) { # interactive()
car_at(lon = -40.5, lat = -9.2)
}
```
