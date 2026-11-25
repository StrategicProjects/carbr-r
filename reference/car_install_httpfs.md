# Instalar a extensão `httpfs` do DuckDB

Para ler só os trechos necessários dos arquivos remotos, o `carbr` usa o
DuckDB com a extensão oficial `httpfs` (código aberto, licença MIT). O
DuckDB a baixa do seu próprio repositório de extensões para a pasta de
extensões dele, fora das pastas do `carbr`; por isso a instalação só é
feita com a sua confirmação.

## Usage

``` r
car_install_httpfs()
```

## Value

`TRUE`, invisível, se a extensão está instalada ao final.

## Details

Em sessão interativa, o pacote pergunta na primeira leitura remota. Em
scripts, relatórios e automações, chame `car_install_httpfs()` uma vez
(a instalação fica guardada para as próximas sessões) ou defina
`options(carbr.install_httpfs = TRUE)`.

## Examples

``` r
if (FALSE) { # interactive()
car_install_httpfs()
}
```
