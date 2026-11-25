# Inconsistências do cadastro

O CAR é **autodeclarado**: quem desenha o perímetro e informa os dados é
o próprio declarante, e a conferência vem depois, na análise. Enquanto
ela não chega, o cadastro guarda sobreposições, imóveis fora do
município informado e áreas que não fecham com o território. Este guia
mostra como encontrar essas inconsistências com o `carbr`, do país até
um município.

Nada aqui é juízo sobre um imóvel em particular: são sinais para
orientar a análise e para quem usa os dados saber o que tem em mãos.

``` r

library(carbr)
library(dplyr)
library(ggplot2)
library(sf)

# Malhas do IBGE, direto da API de malhas, em SIRGAS 2000.
ibge_mesh <- function(path) {
  read_sf(paste0(
    "https://servicodados.ibge.gov.br/api/v3/malhas/", path,
    "formato=application/vnd.geo%2Bjson&qualidade=intermediaria"
  )) |>
    st_transform(4674)
}
```

## O que a carga já registra

Ao republicar os dados, o `carbr` anota no catálogo o que encontrou em
cada UF: geometrias inválidas (com autointerseção, por exemplo) e
imóveis cujo código começa com a sigla de outra UF.

``` r

cat <- car_catalog()
cat |>
  arrange(desc(invalid_geometries)) |>
  select(state, properties, invalid_geometries, registered_in_other_state)
#> # A tibble: 27 × 4
#>   state properties invalid_geometries registered_in_other_state
#>   <chr>      <int>              <int>                     <int>
#> 1 MG       1185013                597                         0
#> 2 SP        474172                498                         0
#> 3 GO        245524                210                         4
#> 4 PR        559480                185                         0
#> 5 MS         90552                156                         0
#> 6 SC        437300                134                         0
#> # ℹ 21 more rows
```

São 2748 geometrias inválidas no país, mantidas na publicação e marcadas
na coluna `geometry_valid`, e 29 imóveis com código de outra UF.

## O país inteiro: sobreposição e imóveis fora do município

Dois sinais são calculados na publicação para cada imóvel não cancelado,
e ficam prontos para consulta: a parcela da área sobreposta a outros
imóveis do estado e a parcela que fica fora do município declarado.
[`car_quality_summary()`](https://castlaboratory.github.io/carbr-r/reference/car_quality.md)
traz o resumo por município; somando por UF:

``` r

quality <- car_quality_summary()

by_state <- quality |>
  group_by(state) |>
  summarise(
    properties = sum(properties),
    overlapping_half = sum(overlapping_half),
    outside_half = sum(outside_half)
  ) |>
  mutate(
    share_overlapping = round(100 * overlapping_half / properties, 1),
    share_outside = round(100 * outside_half / properties, 2)
  ) |>
  arrange(desc(share_overlapping))
by_state |> print(n = 27)
#> # A tibble: 27 × 6
#>    state properties overlapping_half outside_half share_overlapping
#>    <chr>      <int>            <int>        <int>             <dbl>
#>  1 DF         20826            15830           10              76  
#>  2 AC         57680            36265          294              62.9
#>  3 RR         27139            16801          215              61.9
#>  4 AP         16906             9983          192              59.1
#>  5 MA        414258           238954         8819              57.7
#>  6 MT        206064            97781         3397              47.5
#>  7 AM         95521            44325          780              46.4
#>  8 PA        345391           157621         2513              45.6
#>  9 RO        188779            75054         1790              39.8
#> 10 AL        141643            55653         3422              39.3
#> 11 PI        335190           109991         7123              32.8
#> 12 CE        406007           126627         7794              31.2
#> 13 MG       1175484           367167        14066              31.2
#> 14 PE        434153           130542         8665              30.1
#> 15 SE        124631            37085         1527              29.8
#> 16 RN        116984            34708         3280              29.7
#> 17 PB        220048            53737         5862              24.4
#> 18 GO        242639            54527         2742              22.5
#> 19 RJ         68625            14892         1095              21.7
#> 20 SC        435122            79425         6457              18.3
#> 21 ES        128629            23151          982              18  
#> 22 PR        552854            96564         4687              17.5
#> 23 RS        676157           100100         6930              14.8
#> 24 SP        451407            65649         5615              14.5
#> 25 MS         88788            11171          845              12.6
#> 26 TO        103190            12743         1182              12.3
#> 27 BA       1331675            45222        17019               3.4
#>    share_outside
#>            <dbl>
#>  1          0.05
#>  2          0.51
#>  3          0.79
#>  4          1.14
#>  5          2.13
#>  6          1.65
#>  7          0.82
#>  8          0.73
#>  9          0.95
#> 10          2.42
#> 11          2.13
#> 12          1.92
#> 13          1.2 
#> 14          2   
#> 15          1.23
#> 16          2.8 
#> 17          2.66
#> 18          1.13
#> 19          1.6 
#> 20          1.48
#> 21          0.76
#> 22          0.85
#> 23          1.02
#> 24          1.24
#> 25          0.95
#> 26          1.15
#> 27          1.28
```

No país, 25% dos imóveis não cancelados têm mais da metade da área
sobreposta a outros cadastros, e 117303 têm mais da metade da área fora
do município em que foram registrados. A diferença entre os estados é
grande:

``` r

states <- ibge_mesh("paises/BR?intrarregiao=UF&")
ufs <- c(
  "11" = "RO", "12" = "AC", "13" = "AM", "14" = "RR", "15" = "PA", "16" = "AP", "17" = "TO",
  "21" = "MA", "22" = "PI", "23" = "CE", "24" = "RN", "25" = "PB", "26" = "PE", "27" = "AL",
  "28" = "SE", "29" = "BA", "31" = "MG", "32" = "ES", "33" = "RJ", "35" = "SP", "41" = "PR",
  "42" = "SC", "43" = "RS", "50" = "MS", "51" = "MT", "52" = "GO", "53" = "DF"
)

states |>
  mutate(state = ufs[codarea]) |>
  left_join(by_state, by = "state") |>
  ggplot() +
  geom_sf(aes(fill = share_overlapping), colour = "white", linewidth = 0.2) +
  scale_fill_gradient(
    low = "#fff4e6", high = "#c92a2a", limits = c(0, NA),
    labels = function(x) paste0(x, "%"), name = "Imóveis com mais\nda metade da\nárea sobreposta"
  ) +
  labs(
    title = "Sobreposição entre imóveis do CAR, por UF",
    caption = "Fontes: SFB/Sicar, via carbr; malha do IBGE. Imóveis não cancelados."
  ) +
  theme_void() +
  theme(plot.title = element_text(face = "bold"))
```

![Mapa do Brasil com a parcela dos imóveis de cada UF que têm mais da
metade da área sobreposta.](inconsistencias-brasil-1.png)

plot of chunk brasil

Sobreposição não é sinônimo de disputa: entra na conta o mesmo imóvel
declarado duas vezes e o lote que fica dentro de um assentamento. É um
sinal de onde a análise tem mais a conferir. Os municípios com mais
casos:

``` r

quality |>
  arrange(desc(overlapping_half)) |>
  select(state, municipality, properties, overlapping_half, outside_half)
#> # A tibble: 5,563 × 5
#>   state municipality       properties overlapping_half outside_half
#>   <chr> <chr>                   <int>            <int>        <int>
#> 1 DF    Brasília                20826            15830           10
#> 2 RO    Porto Velho             23819            14018           53
#> 3 MG    Januária                12397             9113           90
#> 4 MA    Caxias                  10714             7716          154
#> 5 PA    Marabá                   9638             7454           56
#> 6 RO    Machadinho D'Oeste       8895             7100           37
#> # ℹ 5,557 more rows
```

[`car_quality()`](https://castlaboratory.github.io/carbr-r/reference/car_quality.md)
desce ao imóvel. Mais adiante, este guia refaz a conta de um município
passo a passo, para mostrar de onde os números vêm.

## Terras indígenas e unidades de conservação

O mesmo resumo traz quantos imóveis têm mais de 1% da área dentro de uma
terra indígena (camada da Funai, em todas as fases do processo) ou de
uma unidade de conservação (Cadastro Nacional de Unidades de
Conservação, do MMA). Nas unidades de conservação o grupo importa: as de
proteção integral, como parques e estações ecológicas, em regra não
admitem imóveis privados; as de uso sustentável incluem as áreas de
proteção ambiental (APA) e as reservas particulares (RPPN), onde a
propriedade privada é normal.

``` r

protected <- quality |>
  group_by(state) |>
  summarise(
    properties = sum(properties),
    indigenous = sum(indigenous),
    strict_protection = sum(strict_protection),
    sustainable_use = sum(sustainable_use)
  )

protected |>
  summarise(across(-state, sum))
#> # A tibble: 1 × 4
#>   properties indigenous strict_protection sustainable_use
#>        <int>      <int>             <int>           <int>
#> 1    8405790      13528             67009          554124
```

``` r

protected |>
  tidyr::pivot_longer(c(indigenous, strict_protection), names_to = "kind", values_to = "n") |>
  mutate(
    kind = c(indigenous = "Terra indígena", strict_protection = "Proteção integral")[kind],
    state = reorder(state, n, sum)
  ) |>
  ggplot(aes(n, state, fill = kind)) +
  geom_col() +
  scale_fill_manual(values = c("Terra indígena" = "#c2255c", "Proteção integral" = "#2b8a3e"), name = NULL) +
  scale_x_continuous(labels = function(x) format(x, big.mark = ".", decimal.mark = ",")) +
  labs(
    title = "Imóveis do CAR sobre terra indígena ou unidade de proteção integral",
    subtitle = "Imóveis não cancelados com mais de 1% da área dentro dessas áreas",
    x = NULL, y = NULL,
    caption = "Fontes: SFB/Sicar, via carbr; Funai; CNUC/MMA."
  ) +
  theme_minimal() +
  theme(legend.position = "bottom", plot.title = element_text(face = "bold"))
```

![Barras horizontais com o número de imóveis de cada UF em terra
indígena e em unidade de conservação de proteção
integral.](inconsistencias-protegidas-1.png)

plot of chunk protegidas

Os municípios com mais casos, em cada tipo:

``` r

quality |>
  arrange(desc(indigenous)) |>
  select(state, municipality, properties, indigenous, indigenous_ha)
#> # A tibble: 5,563 × 5
#>   state municipality        properties indigenous indigenous_ha
#>   <chr> <chr>                    <int>      <int>         <dbl>
#> 1 BA    Abaré                     2167       1114         9997.
#> 2 MA    Fernando Falcão           1291        658       640981.
#> 3 AL    Palmeira dos Índios       5745        481         4111.
#> 4 MG    Itacarambi                2458        448        26549.
#> 5 MA    Grajaú                    5508        370       106598.
#> 6 AM    Manicoré                  2541        345      2940910.
#> # ℹ 5,557 more rows

quality |>
  arrange(desc(strict_protection)) |>
  select(state, municipality, properties, strict_protection, strict_protection_ha)
#> # A tibble: 5,563 × 5
#>   state municipality  properties strict_protection strict_protection_ha
#>   <chr> <chr>              <int>             <int>                <dbl>
#> 1 MG    Januária           12397              2377              263163.
#> 2 RO    Porto Velho        23819              1773              359216.
#> 3 MG    Itamonte            1854              1384               29674.
#> 4 AM    Canutama            2883              1313              685991.
#> 5 RJ    Nova Friburgo       3577              1287               32540.
#> 6 BA    Sento Sé            6649               895              157951.
#> # ℹ 5,557 more rows
```

Por imóvel,
[`car_quality()`](https://castlaboratory.github.io/carbr-r/reference/car_quality.md)
traz a parcela da área e o nome da terra indígena ou da unidade de
conservação. É o que
[`car_check()`](https://castlaboratory.github.io/carbr-r/reference/car_check.md)
usa na triagem: um cadastro ativo passa de `"ok"` a `"attention"` quando
mais de 1% da área está em terra indígena ou em unidade de proteção
integral, e a nota diz qual.

``` r

aguas_belas <- car_quality("PE", municipality = "Águas Belas")

aguas_belas |>
  filter(indigenous_share > 0.5) |>
  select(property_code, indigenous_share, indigenous_land) |>
  head(3)
#> # A tibble: 3 × 3
#>   property_code                               indigenous_share indigenous_land
#>   <chr>                                                  <dbl> <chr>          
#> 1 PE-2600500-385FDF5753EB45ACBB8541F300FB68F6                1 Fulni-ô        
#> 2 PE-2600500-4D7A545AB67940E78FA69D3E278F9B6D                1 Fulni-ô        
#> 3 PE-2600500-5244FB34CF6E4D38BD3F2D57D4DFD337                1 Fulni-ô

car_check(head(aguas_belas$property_code[aguas_belas$indigenous_share > 0.5], 2)) |>
  select(check, note)
#> # A tibble: 2 × 2
#>   check    
#>   <chr>    
#> 1 attention
#> 2 attention
#>   note                                                                          
#>   <chr>                                                                         
#> 1 Analisado, com notificação sem resposta do declarante. Sobrepõe terra indígen…
#> 2 Analisado, com notificação sem resposta do declarante. Sobrepõe terra indígen…
```

O sinal vem de perímetros autodeclarados cruzados com limites oficiais,
e não é uma conclusão sobre o imóvel: há terras indígenas ainda em
estudo, e cadastros anteriores à criação de uma unidade de conservação.

## O código diz um município, o cadastro diz outro

O código do imóvel traz o município em que ele foi registrado
(`UF-0000000-…`). Em Pernambuco, comparando com a coluna
`municipality_code`:

``` r

moved <- car_tbl("PE") |>
  mutate(code_municipality = substr(property_code, 4L, 10L)) |>
  filter(code_municipality != as.character(municipality_code)) |>
  select(property_code, municipality, area_ha) |>
  collect()

nrow(moved)
#> [1] 1138
moved |> count(municipality, sort = TRUE)
#> # A tibble: 163 × 2
#>   municipality     n
#>   <chr>        <int>
#> 1 Araripina      106
#> 2 Trindade       102
#> 3 Pedra           79
#> 4 Itaíba          47
#> 5 Itapetim        25
#> 6 Ouricuri        25
#> # ℹ 157 more rows
```

Nem todo caso é erro — imóveis mudam de município quando a base
municipal é atualizada —, mas é uma lista curta para conferir.

## Mais área declarada do que território

Somando a área declarada dos imóveis de cada município e dividindo pela
área do município na malha do IBGE, o resultado não deveria passar de 1.
Passa em vários.

``` r

mesh <- ibge_mesh("estados/PE?intrarregiao=municipio&")
mesh$territory_ha <- as.numeric(st_area(mesh)) / 1e4

ratio <- mesh |>
  transmute(municipality_code = as.integer(codarea), territory_ha) |>
  left_join(car_municipalities("PE"), by = "municipality_code") |>
  mutate(ratio = area_ha / territory_ha)

ratio |>
  st_drop_geometry() |>
  arrange(desc(ratio)) |>
  select(municipality, properties, area_ha, territory_ha, ratio)
#> # A tibble: 185 × 5
#>   municipality properties area_ha territory_ha ratio
#>   <chr>             <int>   <dbl>        <dbl> <dbl>
#> 1 Catende            1289  42584.       20837.  2.04
#> 2 Jaqueira           1203  16282.        8773.  1.86
#> 3 Rio Formoso         776  37162.       22932.  1.62
#> 4 Cortês              756  14887.       10327.  1.44
#> 5 Primavera           620  16195.       11245.  1.44
#> 6 Ribeirão            799  39829.       29218.  1.36
#> # ℹ 179 more rows
```

Em 35 dos 185 municípios de Pernambuco o cadastro soma mais área do que
o município tem; em Catende, o dobro. A concentração na Zona da Mata
sugere sobreposição sistemática entre imóveis, não erro isolado.

``` r

ratio |>
  mutate(class = cut(
    ratio, c(0, 0.5, 0.8, 1, 1.5, Inf),
    labels = c("até 50%", "50 a 80%", "80 a 100%", "100 a 150%", "mais de 150%")
  )) |>
  ggplot() +
  geom_sf(aes(fill = class), colour = "white", linewidth = 0.1) +
  scale_fill_manual(
    values = c("#e8f1e4", "#b7d3ad", "#7fae78", "#f08c4a", "#c92a2a"),
    na.translate = FALSE, name = "Área declarada /\nárea do município"
  ) +
  coord_sf(xlim = c(-41.4, -34.8), ylim = c(-9.5, -7.25)) +
  labs(
    title = "Onde o CAR declara mais área do que o município tem",
    caption = "Fontes: SFB/Sicar, via carbr; malha municipal do IBGE."
  ) +
  theme_void() +
  theme(plot.title = element_text(face = "bold"))
```

![Mapa de Pernambuco com a razão entre área declarada no CAR e área do
município.](inconsistencias-razao-1.png)

plot of chunk razao

## Dentro de um município: Petrolina

Com os perímetros, dá para ir ao detalhe. Os imóveis não cancelados de
Petrolina e o limite do município:

``` r

petrolina <- car_properties("PE", municipality = "Petrolina") |>
  filter(status != "cancelled", geometry_valid)
boundary <- mesh |> filter(codarea == "2611101")
```

### Imóveis fora do município

Recortando cada imóvel pelo limite do município, em coordenadas planas
para medir em hectares, sai a parcela da área que fica do lado de fora.
Faixas estreitas na divisa são esperadas, porque o traçado do IBGE e o
do declarante nunca coincidem; o sinal é o imóvel com mais da metade da
área fora.

``` r

sf_use_s2(FALSE)
utm <- st_transform(petrolina, 31984)
inside <- st_intersection(select(utm, property_code), st_geometry(st_transform(boundary, 31984)))
inside_ha <- setNames(as.numeric(st_area(inside)) / 1e4, inside$property_code)

geometry_ha <- as.numeric(st_area(utm)) / 1e4
outside_share <- 1 - coalesce(inside_ha[utm$property_code], 0) / geometry_ha
petrolina$outside <- outside_share > 0.5

petrolina |>
  st_drop_geometry() |>
  summarise(properties = n(), outside_ha = sum(area_ha[outside]), outside = sum(outside))
#> # A tibble: 1 × 3
#>   properties outside_ha outside
#>        <int>      <dbl>   <int>
#> 1      10849      3359.      90
```

``` r

ggplot() +
  geom_sf(data = boundary, fill = "#f4f8f1", colour = "#123a23", linewidth = 0.6) +
  geom_sf(data = filter(petrolina, !outside), fill = "#8fbf9f", colour = NA, alpha = 0.6) +
  geom_sf(data = filter(petrolina, outside), fill = "#c92a2a", colour = "#c92a2a", linewidth = 0.3) +
  labs(
    title = "Imóveis registrados em Petrolina que ficam fora do município",
    subtitle = "Em vermelho, os que têm mais da metade da área fora do limite do IBGE",
    caption = "Fontes: SFB/Sicar, via carbr; malha municipal do IBGE."
  ) +
  theme_void() +
  theme(plot.title = element_text(face = "bold"))
```

![Mapa de Petrolina com os imóveis fora do limite municipal em
destaque.](inconsistencias-fora-1.png)

plot of chunk fora

### Sobreposições

[`st_overlaps()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html)
aponta, para cada imóvel, os outros com que ele divide área (tocar na
divisa não conta):

``` r

overlaps <- lengths(st_overlaps(utm))

summed_ha <- sum(geometry_ha)
covered_ha <- as.numeric(st_area(st_union(utm))) / 1e4

tibble::tibble(
  properties = nrow(utm),
  overlapping = sum(overlaps > 0),
  summed_ha = round(summed_ha),
  covered_ha = round(covered_ha),
  double_counted_ha = round(summed_ha - covered_ha)
)
#> # A tibble: 1 × 5
#>   properties overlapping summed_ha covered_ha double_counted_ha
#>        <int>       <int>     <dbl>      <dbl>             <dbl>
#> 1      10849        8462    408603     367152             41451
```

78% dos imóveis sobrepõem ao menos um vizinho, quase sempre em faixas
estreitas na divisa. Somadas, as áreas passam em 41 mil hectares a área
de fato coberta. Os casos que mais pesam são poucos:

``` r

petrolina |>
  st_drop_geometry() |>
  mutate(neighbours = overlaps) |>
  arrange(desc(neighbours)) |>
  select(property_code, area_ha, fiscal_modules, size_class, neighbours)
#> # A tibble: 10,849 × 5
#>   property_code                               area_ha fiscal_modules size_class
#>   <chr>                                         <dbl>          <dbl> <chr>     
#> 1 PE-2611101-588BC484570D440484F527F07DF5AFFA  81579.          0.521 small     
#> 2 PE-2611101-5316F05D569C41C4847C52AF2C7E5CCB   6648.          0.623 small     
#> 3 PE-2611101-5149DB80F9E54FDDB445BDC40DF501AF    361.          6.56  medium    
#> 4 PE-2611101-0B75BD9F97224B73A761792FC4095A9C    306.          5.56  medium    
#> 5 PE-2611101-961DA0E4B2FA4FA6BA6601588C06310A    143.          2.54  small     
#> 6 PE-2611101-CB1BE273577643AD9BC07FB09008FB34    306.          5.56  medium    
#>   neighbours
#>        <int>
#> 1        325
#> 2         49
#> 3         41
#> 4         40
#> 5         26
#> 6         26
#> # ℹ 10,843 more rows
```

### “Pequeno” nem sempre é pequeno

O porte (`size_class`) vem dos módulos fiscais informados pelo Sicar,
não da área. Em assentamentos e territórios de povos e comunidades
tradicionais, um único cadastro cobre muitas famílias, e um perímetro de
milhares de hectares aparece com menos de quatro módulos. Em Pernambuco,
os imóveis “pequenos” com mais de 440 hectares — quatro vezes o maior
módulo fiscal do país:

``` r

car_tbl("PE") |>
  filter(size_class == "small", area_ha > 440) |>
  group_by(property_type) |>
  summarise(properties = n(), area_ha = sum(area_ha, na.rm = TRUE)) |>
  collect()
#> # A tibble: 3 × 3
#>   property_type         properties area_ha
#>   <chr>                      <dbl>   <dbl>
#> 1 settlement                   432 651693.
#> 2 rural_property                 1    926.
#> 3 traditional_community         65 164138.
```

Quem conta “pequenos produtores” pelo porte deve separar o tipo do
imóvel (`property_type`) antes.

## O que fazer com isso

Cada sinal acima vira uma lista de imóveis: `property_code` leva ao
cadastro, e
[`car_property()`](https://castlaboratory.github.io/carbr-r/reference/car_property.md)
devolve o perímetro. Para repetir a análise em outro município ou outra
UF, basta trocar os argumentos.
