# Tipologia dos municípios

Cada município entra num de cinco grupos, pelo perfil do seu cadastro: o
porte dos imóveis, em que etapa a análise está e quanto os cadastros se
sobrepõem. Os grupos são achados por agrupamento (k-médias) sobre sete
indicadores e ficam fixos de uma atualização para a outra, de modo que
dá para acompanhar um município mudando de grupo. Municípios com menos
de 30 imóveis não cancelados ficam em `"few"`.

## Usage

``` r
car_typology(state = NULL)

car_typology_groups()
```

## Arguments

- state:

  Sigla de uma ou mais UFs; `NULL` (padrão) traz o país inteiro.

## Value

`car_typology()`: um tibble com uma linha por município: `state`,
`municipality_code`, `municipality`, `typology` (o código do grupo),
`typology_label` (o nome), `properties` e os sete indicadores.
`car_typology_groups()`: um tibble com uma linha por grupo: `typology`,
`typology_label`, `description` (o que o distingue), `municipalities` e
`properties` (quantos municípios e imóveis estão nele na publicação
atual).

## Details

Os indicadores, todos sobre os imóveis não cancelados do município:

- `small_share`: parcela de imóveis pequenos (até 4 módulos fiscais);

- `large_area_share`: parcela da área declarada que está em imóveis
  grandes;

- `waiting_share`, `notified_share` e `analysed_share`: parcela
  aguardando análise, notificada sem resposta e já analisada ou em
  análise;

- `overlap_share`: parcela com mais da metade da área sobreposta a
  outros cadastros;

- `coverage`: área declarada dividida pela área do município (limitada a
  2).

## Examples

``` r
if (FALSE) { # interactive()
car_typology("PE")
car_typology_groups()
}
```
