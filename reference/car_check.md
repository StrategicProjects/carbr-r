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
`area_ha`, `fiscal_modules`, `state`, `municipality` e `created_at`.

## Details

O resultado (`check`) é uma classificação do pacote, não uma regra
oficial:

- `"ok"`: cadastro ativo, sem notificação pendente;

- `"attention"`: cadastro pendente, ou analisado com notificação ainda
  sem resposta do declarante;

- `"blocked"`: cadastro cancelado ou suspenso;

- `"not_found"`: código que não está na publicação (pode ter sido
  cadastrado depois da última atualização);

- `"invalid"`: texto que não tem o formato de um código do CAR.

A verificação diz só o que a camada pública traz. Não cobre embargos,
sobreposição com terras indígenas ou unidades de conservação, nem
substitui a consulta oficial ao Sicar.

## Examples

``` r
if (FALSE) { # interactive()
car_check(c(
  "PE-2611101-588BC484570D440484F527F07DF5AFFA",
  "PE-2611101-00000000000000000000000000000000"
))
}
```
