# Indicadores de qualidade do cadastro

Sinais calculados na publicação para cada imóvel não cancelado:

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

Um tibble. `car_quality()`: `property_code`, `municipality_code` e os
indicadores acima; junte a
[`car_properties()`](https://castlaboratory.github.io/carbr-r/reference/car_properties.md)
por `property_code`. Zero linhas (com aviso) se a publicação não
responder ou não trouxer os indicadores; as colunas de terras indígenas
e unidades de conservação vêm vazias se a publicação ainda não as traz.

## Details

- `overlap_count` e `overlap_share`: com quantos outros imóveis do
  estado ele divide área, e que parcela da área dele está sobreposta (a
  soma das interseções com cada vizinho, limitada a 1);

- `outside_share`: que parcela da área fica fora do município declarado,
  pela malha municipal do IBGE;

- `indigenous_share`: que parcela fica dentro de terras indígenas
  (Funai, todas as fases do processo), com o nome da principal em
  `indigenous_land`;

- `strict_protection_share` e `sustainable_use_share`: que parcela fica
  dentro de unidades de conservação de proteção integral e de uso
  sustentável (CNUC/MMA), com o nome e a categoria da principal em
  `conservation_unit` e `conservation_category` (a de proteção integral,
  se houver);

- `embargo_count` e `embargo_share`: quantos embargos ambientais ativos
  do Ibama alcançam o imóvel e que parcela da área está embargada (só os
  termos que têm o polígono da área; os demais contam pelo ponto de
  referência);

- `public_forest_share`: que parcela fica dentro de florestas públicas
  não destinadas ("tipo B"), pelo Cadastro Nacional de Florestas
  Públicas, do Serviço Florestal.

`car_quality()` traz os indicadores por imóvel; `car_quality_summary()`,
o resumo por município: imóveis não cancelados (`properties`), quantos
têm sobreposição acima de 1% (`overlapping`) e de 50% da área
(`overlapping_half`), os hectares sobrepostos (`overlap_ha`, somando os
dois lados de cada par), e quantos imóveis (`outside_half`) e hectares
(`outside_ha`) ficam fora do município declarado; e, para terras
indígenas (`indigenous`), unidades de proteção integral
(`strict_protection`) e de uso sustentável (`sustainable_use`), quantos
imóveis têm mais de 1% da área dentro delas e quantos hectares (`*_ha`);
quantos imóveis têm embargo ativo do Ibama (`embargoed`) e os hectares
embargados (`embargo_ha`); e quantos têm mais de 1% da área em floresta
pública tipo B (`public_forest`, `public_forest_ha`).

Sobreposição entre imóveis não é sinônimo de disputa: inclui imóvel
declarado duas vezes e lote dentro de assentamento; a comparação é só
entre imóveis do mesmo estado. Estar em unidade de uso sustentável
também não é irregularidade: áreas de proteção ambiental (APA) e
reservas particulares (RPPN) admitem imóveis privados. As edições das
camadas estão em `source$protected_areas` no catálogo.

## Examples

``` r
if (FALSE) { # interactive()
car_quality("PE", municipality = "Petrolina")
car_quality_summary("PE")
}
```
