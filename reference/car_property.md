# Um imóvel pelo código

Um imóvel pelo código

## Usage

``` r
car_property(code, geometry = TRUE)
```

## Arguments

- code:

  Um ou mais códigos de imóvel no CAR (`UF-0000000-identificador`).

- geometry:

  Se `TRUE` (padrão), devolve o perímetro: um objeto `sf` quando o
  pacote `sf` está instalado, senão WKB. `FALSE` não transfere a
  geometria e é bem mais rápido.

## Value

Um tibble ou objeto `sf` com uma linha por código encontrado.

## Examples

``` r
if (FALSE) { # interactive()
car_property("PE-2611101-588BC484570D440484F527F07DF5AFFA")
}
```
