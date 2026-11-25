# carbr <a href="https://strategicprojects.github.io/carbr-r/"><img src="man/figures/logo.svg" align="right" height="139" alt="carbr website" /></a>

[![R-CMD-check](https://github.com/StrategicProjects/carbr-r/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/StrategicProjects/carbr-r/actions/workflows/R-CMD-check.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Os imóveis rurais declarados no **Cadastro Ambiental Rural (CAR)** no R, sem
baixar a base inteira.

O `carbr` lê uma republicação dos dados públicos do Sicar em GeoParquet. Cada
consulta — por UF, município, situação, porte, retângulo, ponto ou código do
imóvel — transfere só os trechos do arquivo de que precisa, e não passa pelos
servidores do Sicar.

## Instalação

```r
# install.packages("pak")
pak::pak("StrategicProjects/carbr-r")
```

Para ler só os trechos necessários dos arquivos remotos, o `carbr` usa o DuckDB com a
extensão oficial `httpfs` (código aberto, MIT). Na primeira consulta, em sessão interativa, o
pacote pergunta se pode instalá-la. Em scripts e relatórios, rode uma vez:

```r
carbr::car_install_httpfs()
```

## Uso

```r
library(carbr)

car_catalog()                       # UFs publicadas, versão e qualidade da carga
car_summary(c("state", "size_class"))   # totais do país, sem ler os imóveis
car_municipalities("PE")            # resumo por município

# Imóveis grandes de Petrolina, como objeto sf
car_properties("PE", municipality = "Petrolina", size_class = "large")

# Cadastros pendentes do estado, sem transferir a geometria
car_properties("PE", status = "pending", geometry = FALSE)

car_at(lon = -40.5, lat = -9.2)     # que imóveis estão declarados neste ponto?
car_property("PE-2611101-588BC484570D440484F527F07DF5AFFA")

# Qualquer outra consulta, com dplyr, direto no arquivo remoto
car_tbl("PE") |>
  dplyr::count(status, size_class) |>
  dplyr::collect()
```

| Função | Para quê |
|---|---|
| `car_catalog()` | O que está publicado, com versão e indicadores de qualidade |
| `car_dictionary()` | Dicionário de dados: coluna, nome no Sicar, descrição |
| `car_summary()` | Totais pré-calculados por UF, situação, porte, tipo, etapa da análise e ano |
| `car_municipalities()` | Resumo por município |
| `car_properties()` | Imóveis de uma UF, com filtros aplicados antes da leitura |
| `car_property()` | Um imóvel pelo código |
| `car_at()` | Imóveis que contêm um ponto |
| `car_tbl()` | Tabela preguiçosa para consultas com `dplyr` |
| `car_cite()` | Como citar os dados |

## Guias

- [Primeiros passos](https://strategicprojects.github.io/carbr-r/articles/carbr.html)
- [Inconsistências do cadastro](https://strategicprojects.github.io/carbr-r/articles/inconsistencias.html): sobreposições, imóveis fora do município, área declarada maior que o território.
- [Onde a análise está parada](https://strategicprojects.github.io/carbr-r/articles/analise.html): as etapas da análise por UF e quem aguarda resposta à notificação.

## Os dados

- **Origem:** serviço público do Sicar, do Serviço Florestal Brasileiro. O cadastro é
  autodeclarado: há sobreposições entre imóveis, e a presença no CAR não comprova domínio.
- **Conteúdo:** o perímetro declarado e dez atributos de cada imóvel (código, situação, etapa da
  análise, tipo, data, área, módulos fiscais, município). Não há dado pessoal.
- **Cobertura:** as 27 UFs, cerca de 8,6 milhões de imóveis. `car_catalog()` mostra o que está
  publicado e a data.
- **Endereço:** o padrão é um bucket público; `options(carbr.base_url = )` ou a variável
  `CAR_URL` apontam para um espelho compatível com S3 ou para uma pasta local.

As mesmas funções existem em Python: [carbr-py](https://github.com/StrategicProjects/carbr-py).

## Licença

Código sob licença MIT. Os dados são do Sicar; use `car_cite()` para citá-los.
