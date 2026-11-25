# Imóveis rurais declarados no CAR

Os imóveis de uma UF, com filtros aplicados antes da leitura: só os
trechos do arquivo que atendem ao filtro são transferidos.

## Usage

``` r
car_properties(
  state,
  municipality = NULL,
  status = NULL,
  size_class = NULL,
  property_type = NULL,
  bbox = NULL,
  geometry = TRUE
)
```

## Arguments

- state:

  Sigla de uma ou mais UFs.

- municipality:

  Nomes ou códigos IBGE (7 dígitos) de municípios.

- status:

  Situação do cadastro: `"active"`, `"pending"`, `"suspended"`,
  `"cancelled"`.

- size_class:

  Porte: `"small"` (até 4 módulos fiscais), `"medium"` (acima de 4 até
  15), `"large"`.

- property_type:

  Tipo: `"rural_property"`, `"settlement"`, `"traditional_community"`.

- bbox:

  Retângulo `c(xmin, ymin, xmax, ymax)` em graus (SIRGAS 2000); traz os
  imóveis cujo retângulo envolvente o toca.

- geometry:

  Se `TRUE` (padrão), devolve o perímetro: um objeto `sf` quando o
  pacote `sf` está instalado, senão WKB. `FALSE` não transfere a
  geometria e é bem mais rápido.

## Value

Um tibble ou objeto `sf`, uma linha por imóvel; as colunas estão em
[`car_dictionary()`](https://strategicprojects.github.io/carbr-r/reference/car_dictionary.md).
Zero linhas (com aviso) se a publicação não responder.

## Examples

``` r
if (FALSE) { # interactive()
car_properties("PE", municipality = "Petrolina", size_class = "large")
car_properties("PE", status = "pending", geometry = FALSE)
}
```
