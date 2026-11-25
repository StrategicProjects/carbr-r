# Pasta de cache do carbr

O catálogo, o dicionário e o resumo municipal ficam em cache em disco,
uma pasta por versão do catálogo. Os imóveis não são copiados: cada
consulta lê do arquivo remoto só os trechos de que precisa.
`car_cache_clear()` apaga o cache.

## Usage

``` r
car_cache_dir()

car_cache_clear()
```

## Value

O caminho da pasta de cache (invisível em `car_cache_clear()`).

## Examples

``` r
car_cache_dir()
#> [1] "/home/runner/.cache/R/carbr"
```
