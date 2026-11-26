# Verificar vários imóveis de uma vez

Para uma lista de códigos, diz o que consta de cada um na camada pública
do CAR e resume em um resultado: a triagem que antecede, por exemplo, a
análise de um pedido de crédito rural. Os códigos são agrupados por UF e
município, de modo que uma lista grande lê poucos trechos de cada
arquivo.

## Usage

``` r
car_check(code)
```

## Arguments

- code:

  Códigos de imóvel no CAR (`UF-0000000-identificador`).

## Value

Um tibble com uma linha por código, na ordem dada: `property_code`,
`check`, `note` (o motivo, em português), `stage` (a etapa da análise:
`"waiting"`, `"analysing"`, `"notified"`, `"answered"`, `"done"` ou
`"cancelled"`), `status`, `condition`, `property_type`, `size_class`,
`area_ha`, `fiscal_modules`, `state`, `municipality`, `created_at` e,
para os imóveis não cancelados, `indigenous_share`,
`strict_protection_share`, `sustainable_use_share` (parcelas da área, de
0 a 1), `protected_area` (os nomes das áreas sobrepostas),
`embargo_count` e `embargo_share`.

## Details

O resultado (`check`) é uma classificação do pacote, não uma regra
oficial:

- `"ok"`: cadastro ativo, sem notificação pendente;

- `"attention"`: cadastro pendente, analisado com notificação ainda sem
  resposta do declarante, com mais de 1% da área sobre terra indígena ou
  unidade de conservação de proteção integral, ou com embargo ambiental
  ativo do Ibama;

- `"blocked"`: cadastro cancelado ou suspenso;

- `"not_found"`: código que não está na publicação (pode ter sido
  cadastrado depois da última atualização);

- `"invalid"`: texto que não tem o formato de um código do CAR.

A sobreposição com terras indígenas (Funai) e unidades de conservação
(CNUC/MMA) é calculada na publicação, pelos perímetros declarados. Estar
em unidade de uso sustentável é informado na nota, mas não muda o
resultado: áreas de proteção ambiental e reservas particulares admitem
imóveis privados. Os embargos são os do Ibama (dados abertos, termos não
cancelados e sem desembargo), localizados pelo polígono ou pelo ponto do
termo; não entram embargos estaduais nem do ICMBio. A verificação não
cobre os demais impedimentos do crédito rural (territórios quilombolas,
florestas públicas não destinadas, supressão de vegetação, trabalho
análogo à escravidão) e não substitui a consulta oficial ao Sicar.

## Examples

``` r
if (FALSE) { # interactive()
car_check(c(
  "PE-2611101-588BC484570D440484F527F07DF5AFFA",
  "PE-2611101-00000000000000000000000000000000"
))
}
```
