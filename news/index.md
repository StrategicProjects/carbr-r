# Changelog

## carbr (development version)

- Guia novo, “Triagem para crédito e conformidade”, e seção sobre o
  Sigef no guia de inconsistências.
- [`car_check()`](https://castlaboratory.github.io/carbr-r/reference/car_check.md)
  passa a apontar embargos ambientais ativos do Ibama (`embargo_count`,
  `embargo_share`), que levam o resultado a `"attention"`;
  [`car_quality()`](https://castlaboratory.github.io/carbr-r/reference/car_quality.md)
  e
  [`car_quality_summary()`](https://castlaboratory.github.io/carbr-r/reference/car_quality.md)
  trazem as colunas novas.
- O mesmo para florestas públicas não destinadas (“tipo B”), pelo
  Cadastro Nacional de Florestas Públicas (`public_forest_share`).
- Parcelas georreferenciadas do Sigef (Incra): `sigef_count` e
  `sigef_share` dizem quanto do imóvel coincide com um
  georreferenciamento aprovado; `quilombola_share` e `settlement_share`,
  quanto cai em território quilombola ou assentamento do Sigef. A
  triagem alerta para território quilombola, com cobertura parcial.
- [`car_typology()`](https://castlaboratory.github.io/carbr-r/reference/car_typology.md)
  e
  [`car_typology_groups()`](https://castlaboratory.github.io/carbr-r/reference/car_typology.md):
  tipologia dos municípios em cinco grupos, pelo perfil do cadastro
  (porte dos imóveis, etapa da análise e sobreposição).
- [`car_check()`](https://castlaboratory.github.io/carbr-r/reference/car_check.md)
  passa a considerar a sobreposição com terras indígenas (Funai) e
  unidades de conservação (CNUC/MMA);
  [`car_quality()`](https://castlaboratory.github.io/carbr-r/reference/car_quality.md)
  e
  [`car_quality_summary()`](https://castlaboratory.github.io/carbr-r/reference/car_quality.md)
  trazem as parcelas e os nomes.
- [`car_quality()`](https://castlaboratory.github.io/carbr-r/reference/car_quality.md)
  e
  [`car_quality_summary()`](https://castlaboratory.github.io/carbr-r/reference/car_quality.md):
  indicadores de qualidade do cadastro, por imóvel e por município
  (sobreposição com outros imóveis e área fora do município declarado).
- [`car_check()`](https://castlaboratory.github.io/carbr-r/reference/car_check.md):
  verifica uma lista de códigos de imóvel de uma vez e resume o que
  consta de cada um (`ok`, `attention`, `blocked`, `not_found`,
  `invalid`).

## carbr 0.1.0

- Primeira versão:
  [`car_catalog()`](https://castlaboratory.github.io/carbr-r/reference/car_catalog.md),
  [`car_dictionary()`](https://castlaboratory.github.io/carbr-r/reference/car_dictionary.md),
  [`car_summary()`](https://castlaboratory.github.io/carbr-r/reference/car_summary.md),
  [`car_municipalities()`](https://castlaboratory.github.io/carbr-r/reference/car_municipalities.md),
  [`car_properties()`](https://castlaboratory.github.io/carbr-r/reference/car_properties.md),
  [`car_property()`](https://castlaboratory.github.io/carbr-r/reference/car_property.md),
  [`car_at()`](https://castlaboratory.github.io/carbr-r/reference/car_at.md),
  [`car_tbl()`](https://castlaboratory.github.io/carbr-r/reference/car_tbl.md)
  e
  [`car_cite()`](https://castlaboratory.github.io/carbr-r/reference/car_cite.md).
- Dados das 27 UFs (cerca de 8,6 milhões de imóveis), atualizados toda
  semana.
- [`car_summary()`](https://castlaboratory.github.io/carbr-r/reference/car_summary.md)
  lê um resumo pré-calculado: totais nacionais em segundos.
- Guias: “Primeiros passos”, “Inconsistências do cadastro” e “Onde a
  análise está parada”.
- A extensão `httpfs` do DuckDB só é instalada com confirmação: o pacote
  pergunta em sessão interativa; em scripts,
  [`car_install_httpfs()`](https://castlaboratory.github.io/carbr-r/reference/car_install_httpfs.md).
