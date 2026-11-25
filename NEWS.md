# carbr (development version)

* `car_check()` passa a considerar a sobreposição com terras indígenas (Funai) e unidades de
  conservação (CNUC/MMA); `car_quality()` e `car_quality_summary()` trazem as parcelas e os nomes.
* `car_quality()` e `car_quality_summary()`: indicadores de qualidade do cadastro, por imóvel e por
  município (sobreposição com outros imóveis e área fora do município declarado).
* `car_check()`: verifica uma lista de códigos de imóvel de uma vez e resume o que consta
  de cada um (`ok`, `attention`, `blocked`, `not_found`, `invalid`).

# carbr 0.1.0

* Primeira versão: `car_catalog()`, `car_dictionary()`, `car_summary()`,
  `car_municipalities()`, `car_properties()`, `car_property()`, `car_at()`,
  `car_tbl()` e `car_cite()`.
* Dados das 27 UFs (cerca de 8,6 milhões de imóveis), atualizados toda semana.
* `car_summary()` lê um resumo pré-calculado: totais nacionais em segundos.
* Guias: "Primeiros passos", "Inconsistências do cadastro" e "Onde a análise
  está parada".
* A extensão `httpfs` do DuckDB só é instalada com confirmação: o pacote pergunta
  em sessão interativa; em scripts, `car_install_httpfs()`.
