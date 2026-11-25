# Onde a análise está parada

Cadastrar foi a parte rápida: o país tem mais de 8,5 milhões de imóveis
no CAR. A regularização depende do passo seguinte — o órgão estadual
analisar o cadastro e o produtor responder ao que a análise pede. Este
guia usa a coluna `condition`, a etapa da análise informada pelo Sicar,
para mostrar onde cada UF está e quem espera por quem.

Tudo aqui sai do resumo pré-calculado
([`car_summary()`](https://castlaboratory.github.io/carbr-r/reference/car_summary.md)),
em segundos, menos o mapa do fim, que lê duas colunas de um estado.

``` r

library(carbr)
library(dplyr)
library(ggplot2)
```

## As etapas

O Sicar informa quinze situações de análise. Agrupadas em seis etapas:

``` r

stage <- function(condition) {
  case_when(
    grepl("^Cancelado", condition) ~ "Cancelado",
    condition == "Aguardando análise" ~ "Aguardando análise",
    condition == "Em análise" ~ "Em análise",
    grepl("aguardando atendimento a notificação", condition) ~ "Notificado, sem resposta",
    grepl("após revisão", condition) ~ "Respondeu, aguarda reanálise",
    grepl("^Analisado", condition) ~ "Analisado",
    TRUE ~ "Outro"
  ) |>
    factor(c(
      "Aguardando análise", "Em análise", "Notificado, sem resposta",
      "Respondeu, aguarda reanálise", "Analisado", "Cancelado"
    ))
}

national <- car_summary("condition") |>
  mutate(stage = stage(condition)) |>
  count(stage, wt = properties, name = "properties") |>
  mutate(share = round(100 * properties / sum(properties), 1))
national
#> # A tibble: 6 × 3
#>   stage                        properties share
#>   <fct>                             <int> <dbl>
#> 1 Aguardando análise              5978517  69.7
#> 2 Em análise                       109355   1.3
#> 3 Notificado, sem resposta        1309319  15.3
#> 4 Respondeu, aguarda reanálise     134338   1.6
#> 5 Analisado                        874465  10.2
#> 6 Cancelado                        172067   2
```

Sete em cada dez cadastros ainda não foram analisados. Dos que foram, a
maior parte parou no passo seguinte: 1,3 milhão de imóveis foram
notificados e aguardam resposta do declarante, mais do que os 0,9 milhão
com análise concluída.

## A fila não é a mesma em cada UF

``` r

palette <- c(
  "Aguardando análise" = "#d9d9d9", "Em análise" = "#9ecae1",
  "Notificado, sem resposta" = "#e8590c", "Respondeu, aguarda reanálise" = "#fcc419",
  "Analisado" = "#2b8a3e", "Cancelado" = "#868e96"
)

by_state <- car_summary(c("state", "condition")) |>
  mutate(stage = stage(condition)) |>
  count(state, stage, wt = properties, name = "properties") |>
  group_by(state) |>
  mutate(share = properties / sum(properties)) |>
  ungroup()

order <- by_state |>
  filter(stage == "Aguardando análise") |>
  arrange(desc(share)) |>
  pull(state)

by_state |>
  mutate(state = factor(state, order)) |>
  ggplot(aes(share, state, fill = stage)) +
  geom_col(position = position_stack(reverse = TRUE), width = 0.8) +
  scale_x_continuous(labels = function(x) paste0(100 * x, "%"), expand = c(0, 0)) +
  scale_fill_manual(values = palette, name = NULL) +
  guides(fill = guide_legend(nrow = 2)) +
  labs(
    title = "Em que etapa da análise estão os imóveis de cada UF",
    x = NULL, y = NULL, caption = "Fonte: SFB/Sicar, via carbr."
  ) +
  theme_minimal() +
  theme(legend.position = "bottom", plot.title = element_text(face = "bold"))
```

![Barras horizontais empilhadas com a parcela dos imóveis de cada UF em
cada etapa da análise.](analise-etapas-1.png)

plot of chunk etapas

Há três situações bem diferentes. Em parte dos estados quase nada foi
analisado (cinza). Em alguns a análise andou e concluiu (verde). E em
outros a análise andou, mas parou na notificação (laranja): o órgão fez
a sua parte e a resposta não veio.

``` r

notified <- by_state |>
  filter(stage == "Notificado, sem resposta") |>
  arrange(desc(properties)) |>
  mutate(share = round(100 * share, 1))
notified
#> # A tibble: 25 × 4
#>   state stage                    properties share
#>   <chr> <fct>                         <int> <dbl>
#> 1 PA    Notificado, sem resposta     265238  67.5
#> 2 CE    Notificado, sem resposta     203419  49.5
#> 3 MG    Notificado, sem resposta     161094  13.6
#> 4 PI    Notificado, sem resposta     153090  45.3
#> 5 SP    Notificado, sem resposta     144251  30.4
#> 6 AL    Notificado, sem resposta      97264  67.6
#> # ℹ 19 more rows
```

As cinco primeiras UFs concentram 71% das notificações sem resposta.

## Quem está sem responder

``` r

waiting <- car_summary(c("condition", "size_class")) |>
  filter(stage(condition) == "Notificado, sem resposta") |>
  count(size_class, wt = properties, name = "properties") |>
  mutate(share = round(100 * properties / sum(properties), 1))
waiting
#> # A tibble: 3 × 3
#>   size_class properties share
#>   <chr>           <int> <dbl>
#> 1 large           27771   2.1
#> 2 medium          86308   6.6
#> 3 small         1195240  91.3
```

91,3% são imóveis de até quatro módulos fiscais. É o público que menos
tem acesso a técnico, a ferramenta de geoprocessamento e a quem explique
o relatório da análise — e para quem a pendência no CAR pesa no crédito
rural.

## A notificação envelhece

Pelo ano de criação do cadastro, a resposta não chega com o tempo: de
cada ano desde 2015, entre um oitavo e um quinto dos cadastros está
parado na notificação, e os mais antigos não estão em situação melhor.

``` r

car_summary(c("created_year", "condition")) |>
  mutate(stage = stage(condition)) |>
  count(created_year, stage, wt = properties, name = "properties") |>
  ggplot(aes(created_year, properties / 1e3, fill = stage)) +
  geom_col(position = position_stack(reverse = TRUE)) +
  scale_x_continuous(breaks = 2014:2026) +
  scale_fill_manual(values = palette, name = NULL) +
  guides(fill = guide_legend(nrow = 2)) +
  labs(
    title = "Etapa atual da análise, por ano de criação do cadastro",
    x = NULL, y = "Milhares de imóveis", caption = "Fonte: SFB/Sicar, via carbr."
  ) +
  theme_minimal() +
  theme(legend.position = "bottom", plot.title = element_text(face = "bold"))
```

![Colunas empilhadas com os cadastros por ano de criação e etapa da
análise.](analise-anos-1.png)

plot of chunk anos

## Onde, dentro de um estado

O resumo vai até a UF. Para descer ao município,
[`car_tbl()`](https://castlaboratory.github.io/carbr-r/reference/car_tbl.md)
lê só as duas colunas necessárias do arquivo do estado. No Pará, a UF
com mais notificações sem resposta:

``` r

para <- car_tbl("PA") |>
  count(municipality_code, municipality, condition) |>
  collect() |>
  mutate(stage = stage(condition)) |>
  group_by(municipality_code, municipality) |>
  summarise(
    properties = sum(n),
    notified = sum(n[stage == "Notificado, sem resposta"]),
    .groups = "drop"
  ) |>
  mutate(share = notified / properties)

para |>
  arrange(desc(notified)) |>
  mutate(share = round(100 * share, 1))
#> # A tibble: 144 × 5
#>   municipality_code municipality       properties notified share
#>               <int> <chr>                   <dbl>    <dbl> <dbl>
#> 1           1505064 Novo Repartimento       12492     8782  70.3
#> 2           1504208 Marabá                  12935     8043  62.2
#> 3           1500206 Acará                    9267     7836  84.6
#> 4           1504703 Moju                    12009     7305  60.8
#> 5           1505486 Pacajá                  11170     7169  64.2
#> 6           1507300 São Félix do Xingu      13174     6971  52.9
#> # ℹ 138 more rows
```

``` r

mesh <- sf::read_sf(paste0(
  "https://servicodados.ibge.gov.br/api/v3/malhas/estados/PA?intrarregiao=municipio",
  "&formato=application/vnd.geo%2Bjson&qualidade=intermediaria"
)) |>
  mutate(municipality_code = as.integer(codarea)) |>
  left_join(para, by = "municipality_code")

ggplot(mesh) +
  geom_sf(aes(fill = share), colour = "white", linewidth = 0.1) +
  scale_fill_gradient(
    low = "#fff4e6", high = "#d9480f", na.value = "grey85",
    labels = function(x) paste0(100 * x, "%"), name = "Notificados,\nsem resposta"
  ) +
  labs(
    title = "Pará: imóveis notificados que aguardam resposta do declarante",
    subtitle = "Parcela dos imóveis de cada município",
    caption = "Fontes: SFB/Sicar, via carbr; malha municipal do IBGE."
  ) +
  theme_void() +
  theme(plot.title = element_text(face = "bold"))
```

![Mapa do Pará com a parcela dos imóveis notificados e sem resposta por
município.](analise-para-1.png)

plot of chunk para

É uma lista de onde um mutirão, um sindicato ou um serviço de
atendimento ao produtor rende mais: municípios com muitos imóveis já
analisados à espera de uma resposta que depende só de o declarante
entender o que foi pedido.

## Uma tipologia dos municípios

As etapas da análise, o porte dos imóveis e a sobreposição entre
cadastros variam juntos, e os municípios se parecem em blocos.
[`car_typology()`](https://castlaboratory.github.io/carbr-r/reference/car_typology.md)
resume isso: cada município entra num de cinco grupos, achados por
agrupamento (k-médias) sobre sete indicadores do cadastro. Os grupos
ficam fixos de uma atualização para a outra, de modo que dá para
acompanhar um município mudando de grupo.

``` r

car_typology_groups() |>
  select(typology_label, municipalities, properties, description)
#> # A tibble: 6 × 4
#>   typology_label                       municipalities properties
#>   <chr>                                         <int>      <int>
#> 1 Pequenos imóveis à espera de análise           2419    4120960
#> 2 Análise avançada                                976    1047289
#> 3 Grandes imóveis à espera de análise             804     735672
#> 4 Notificados sem resposta                        732    1346341
#> 5 Muita sobreposição                              588    1154936
#> 6 Poucos cadastros                                 44        592
#>   description                                                                   
#>   <chr>                                                                         
#> 1 Quase só imóveis pequenos, e a grande maioria ainda aguarda a análise.        
#> 2 Boa parte dos cadastros já foi analisada ou está em análise.                  
#> 3 A maior parte da área declarada está em imóveis grandes, e a análise mal come…
#> 4 A análise andou, mas a maioria dos cadastros espera a resposta do declarante. 
#> 5 Mais da metade dos imóveis tem a maior parte da área dentro de outros cadastr…
#> 6 Menos de 30 imóveis não cancelados: pouco para caracterizar o município.
```

O perfil médio de cada grupo mostra de onde vêm os nomes:

``` r

typology <- car_typology()

typology |>
  group_by(typology_label) |>
  summarise(across(small_share:coverage, \(x) round(mean(x, na.rm = TRUE), 2))) |>
  as.data.frame()
#>                         typology_label small_share large_area_share
#> 1                     Análise avançada        0.90             0.28
#> 2  Grandes imóveis à espera de análise        0.73             0.56
#> 3                   Muita sobreposição        0.94             0.33
#> 4             Notificados sem resposta        0.95             0.23
#> 5 Pequenos imóveis à espera de análise        0.96             0.13
#> 6                     Poucos cadastros        0.71             0.37
#>   waiting_share notified_share analysed_share overlap_share coverage
#> 1          0.31           0.19           0.50          0.14     0.91
#> 2          0.67           0.19           0.14          0.21     0.95
#> 3          0.85           0.08           0.07          0.55     1.11
#> 4          0.21           0.57           0.22          0.33     0.81
#> 5          0.92           0.04           0.04          0.18     0.83
#> 6          0.53           0.22           0.26          0.07     0.23
```

``` r

groups <- c(
  "Pequenos imóveis à espera de análise" = "#adb5bd",
  "Grandes imóveis à espera de análise" = "#4c6ef5",
  "Análise avançada" = "#37b24d",
  "Notificados sem resposta" = "#f76707",
  "Muita sobreposição" = "#c2255c",
  "Poucos cadastros" = "#f1f3f5"
)

brazil <- sf::read_sf(paste0(
  "https://servicodados.ibge.gov.br/api/v3/malhas/paises/BR?intrarregiao=municipio",
  "&formato=application/vnd.geo%2Bjson&qualidade=minima"
)) |>
  mutate(municipality_code = as.integer(codarea)) |>
  left_join(typology, by = "municipality_code") |>
  mutate(typology_label = factor(typology_label, names(groups)))

ggplot(brazil) +
  geom_sf(aes(fill = typology_label), colour = NA) +
  scale_fill_manual(values = groups, na.value = "#f1f3f5", na.translate = FALSE, name = NULL) +
  labs(
    title = "Tipologia dos municípios pelo perfil do CAR",
    caption = "Fontes: SFB/Sicar, via carbr; malha municipal do IBGE."
  ) +
  guides(fill = guide_legend(ncol = 2)) +
  theme_void() +
  theme(legend.position = "bottom", plot.title = element_text(face = "bold"))
```

![Mapa do Brasil com os municípios coloridos pelo grupo da
tipologia.](analise-tipologia-1.png)

plot of chunk tipologia

O mapa separa situações que pedem respostas diferentes. Onde a análise
mal começou, o gargalo é a capacidade do órgão ambiental. Onde os
cadastros estão notificados e sem resposta, é o atendimento ao
declarante. Onde a sobreposição domina, é a qualidade do que foi
declarado. E um estado pode ter mais de uma dessas situações:

``` r

typology |>
  count(state, typology_label) |>
  group_by(state) |>
  slice_max(n, n = 1, with_ties = FALSE) |>
  ungroup() |>
  count(typology_label, name = "states")
#> # A tibble: 5 × 2
#>   typology_label                       states
#>   <chr>                                 <int>
#> 1 Análise avançada                          3
#> 2 Grandes imóveis à espera de análise       5
#> 3 Muita sobreposição                        3
#> 4 Notificados sem resposta                  6
#> 5 Pequenos imóveis à espera de análise     10
```
