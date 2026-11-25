# Indicadores de qualidade do cadastro

Dois sinais de inconsistência, calculados na publicação para cada imóvel
não cancelado:

## Usage

``` r
car_quality(state, municipality = NULL)

car_quality_summary(state = NULL)
```

## Arguments

- state:

  Sigla de uma ou mais UFs. Em `car_quality_summary()`, `NULL` (padrão)
  traz todas as publicadas.

- municipality:

  Nomes ou códigos IBGE (7 dígitos) de municípios; lê só os trechos
  deles.

## Value

Um tibble. `car_quality()`: `property_code`, `municipality_code`,
`overlap_count`, `overlap_share` e `outside_share`; junte a
[`car_properties()`](https://castlaboratory.github.io/carbr-r/reference/car_properties.md)
por `property_code`. Zero linhas (com aviso) se a publicação não
responder ou não trouxer os indicadores.

## Details

- `overlap_count` e `overlap_share`: com quantos outros imóveis do
  estado ele divide área, e que parcela da área dele está sobreposta (a
  soma das interseções com cada vizinho, limitada a 1);

- `outside_share`: que parcela da área fica fora do município declarado,
  pela malha municipal do IBGE.

`car_quality()` traz os indicadores por imóvel; `car_quality_summary()`,
o resumo por município: imóveis não cancelados (`properties`), quantos
têm sobreposição acima de 1% (`overlapping`) e de 50% da área
(`overlapping_half`), os hectares sobrepostos (`overlap_ha`, somando os
dois lados de cada par), e quantos imóveis (`outside_half`) e hectares
(`outside_ha`) ficam fora do município declarado.

Sobreposição não é sinônimo de disputa: inclui imóvel declarado duas
vezes e lote dentro de assentamento. A comparação é só entre imóveis do
mesmo estado.

## Examples

``` r
if (FALSE) { # interactive()
car_quality("PE", municipality = "Petrolina")
car_quality_summary("PE")
}
```
