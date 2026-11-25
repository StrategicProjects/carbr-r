# carbr

[![R-CMD-check](https://github.com/castlaboratory/carbr-r/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/castlaboratory/carbr-r/actions/workflows/R-CMD-check.yaml)
[![License:
MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24537631.svg)](https://doi.org/10.5281/zenodo.24537631)

Os imóveis rurais declarados no **Cadastro Ambiental Rural (CAR)** no R,
sem baixar a base inteira.

O `carbr` lê uma republicação dos dados públicos do Sicar em GeoParquet.
Cada consulta — por UF, município, situação, porte, retângulo, ponto ou
código do imóvel — transfere só os trechos do arquivo de que precisa, e
não passa pelos servidores do Sicar.

**Consulta no navegador, sem instalar nada:**
<https://car.castlab.org/index.html>

## Instalação

``` r

# install.packages("pak")
pak::pak("castlaboratory/carbr-r")
```

Para ler só os trechos necessários dos arquivos remotos, o `carbr` usa o
DuckDB com a extensão oficial `httpfs` (código aberto, MIT). Na primeira
consulta, em sessão interativa, o pacote pergunta se pode instalá-la. Em
scripts e relatórios, rode uma vez:

``` r

carbr::car_install_httpfs()
```

## Uso

``` r

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
car_check(codigos)                  # triagem de uma lista de códigos

# Qualquer outra consulta, com dplyr, direto no arquivo remoto
car_tbl("PE") |>
  dplyr::count(status, size_class) |>
  dplyr::collect()
```

| Função | Para quê |
|----|----|
| [`car_catalog()`](https://castlaboratory.github.io/carbr-r/reference/car_catalog.md) | O que está publicado, com versão e indicadores de qualidade |
| [`car_dictionary()`](https://castlaboratory.github.io/carbr-r/reference/car_dictionary.md) | Dicionário de dados: coluna, nome no Sicar, descrição |
| [`car_summary()`](https://castlaboratory.github.io/carbr-r/reference/car_summary.md) | Totais pré-calculados por UF, situação, porte, tipo, etapa da análise e ano |
| [`car_municipalities()`](https://castlaboratory.github.io/carbr-r/reference/car_municipalities.md) | Resumo por município |
| [`car_properties()`](https://castlaboratory.github.io/carbr-r/reference/car_properties.md) | Imóveis de uma UF, com filtros aplicados antes da leitura |
| [`car_property()`](https://castlaboratory.github.io/carbr-r/reference/car_property.md) | Um imóvel pelo código |
| [`car_check()`](https://castlaboratory.github.io/carbr-r/reference/car_check.md) | Verificação de uma lista de códigos de uma vez |
| [`car_at()`](https://castlaboratory.github.io/carbr-r/reference/car_at.md) | Imóveis que contêm um ponto |
| [`car_tbl()`](https://castlaboratory.github.io/carbr-r/reference/car_tbl.md) | Tabela preguiçosa para consultas com `dplyr` |
| [`car_cite()`](https://castlaboratory.github.io/carbr-r/reference/car_cite.md) | Como citar os dados |

## Guias

- [Primeiros
  passos](https://castlaboratory.github.io/carbr-r/articles/carbr.html)
- [Inconsistências do
  cadastro](https://castlaboratory.github.io/carbr-r/articles/inconsistencias.html):
  sobreposições, imóveis fora do município, área declarada maior que o
  território.
- [Onde a análise está
  parada](https://castlaboratory.github.io/carbr-r/articles/analise.html):
  as etapas da análise por UF e quem aguarda resposta à notificação.

## Os dados

- **Origem:** serviço público do Sicar, do Serviço Florestal Brasileiro.
  O cadastro é autodeclarado: há sobreposições entre imóveis, e a
  presença no CAR não comprova domínio.
- **Conteúdo:** o perímetro declarado e dez atributos de cada imóvel
  (código, situação, etapa da análise, tipo, data, área, módulos
  fiscais, município). Não há dado pessoal.
- **Base normativa:** a Instrução Normativa MMA nº 3, de 18/12/2014,
  garante o livre acesso às informações não sigilosas e não pessoais do
  Sicar (arts. 12 e 18). São sigilosas as que identificam proprietários
  ou possuidores ou os associam aos imóveis (art. 4º); nenhuma delas
  está nesta publicação.
- **Finalidade:** pela mesma norma (art. 2º), as informações do CAR se
  destinam a subsidiar políticas, programas, projetos e atividades de
  controle, monitoramento, planejamento ambiental e econômico e combate
  ao desmatamento. O uso para outros fins que cause dano a terceiros
  pode gerar responsabilização.
- **Sem caráter oficial:** é uma republicação independente, feita pelo
  CastLab/UFPE. Não é um produto do Serviço Florestal Brasileiro nem
  substitui o Sicar; em caso de divergência, vale o Sicar.
- **Cobertura:** as 27 UFs, cerca de 8,6 milhões de imóveis.
  [`car_catalog()`](https://castlaboratory.github.io/carbr-r/reference/car_catalog.md)
  mostra o que está publicado e a data.
- **Endereço:** o padrão é um bucket público;
  `options(carbr.base_url = )` ou a variável `CAR_URL` apontam para um
  espelho compatível com S3 ou para uma pasta local.

As mesmas funções existem em Python:
[carbr-py](https://github.com/castlaboratory/carbr-py).

## Como citar

O pacote está arquivado no Zenodo:
[doi:10.5281/zenodo.24537631](https://doi.org/10.5281/zenodo.24537631)
(o DOI aponta sempre para a versão mais recente). Os dados são do Sicar;
use
[`car_cite()`](https://castlaboratory.github.io/carbr-r/reference/car_cite.md)
para citá-los.

## Licença

Código sob licença MIT.
