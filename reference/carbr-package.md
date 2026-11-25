# carbr: Access the Rural Environmental Registry of Brazil ('CAR')

A tidy interface to the rural properties declared in the Rural
Environmental Registry of Brazil ('Cadastro Ambiental Rural', 'CAR'),
republished from the public service of the national system ('Sicar') as
cloud-optimised 'GeoParquet'. Queries by state, municipality, status,
size, bounding box, point or property code read only the parts of the
remote files they need, so no full download of the registry is required.
Results are returned as tibbles or 'sf' objects. Small files are cached
on disk per catalogue version and checked against their published
'SHA-256'. Network failures are handled gracefully.

## Opções do pacote

- `carbr.base_url`: endereço (ou pasta local) da publicação, também
  `CAR_URL`. O padrão é o bucket público; serve para apontar para um
  espelho ou para uma cópia local. A árvore tem `catalog.json`,
  `dictionary.json`, `municipalities/` e `properties/state=<UF>/`.

- `carbr.quiet`: silencia as mensagens informativas. Padrão `TRUE` em
  sessões não interativas.

- `carbr.cache_dir`: local do cache. Padrão
  `tools::R_user_dir("carbr", "cache")` (ou `CAR_CACHE_DIR`).

- `carbr.catalog_max_age`: segundos em que o catálogo em cache vale sem
  consultar o servidor. Padrão 6 horas.

- `carbr.max_tries`, `carbr.timeout`: tentativas (padrão 3, com espera
  exponencial) e tempo limite de cada requisição em segundos (padrão
  60).

## See also

Useful links:

- <https://github.com/StrategicProjects/carbr-r>

- <https://strategicprojects.github.io/carbr-r/>

- Report bugs at <https://github.com/StrategicProjects/carbr-r/issues>

## Author

**Maintainer**: André Leite <leite@castlab.org>
([ORCID](https://orcid.org/0000-0002-4718-9766))

Authors:

- André Leite <leite@castlab.org>
  ([ORCID](https://orcid.org/0000-0002-4718-9766))

- Marcos Wasiliew <marcos.wasiliew@gmail.com>
  ([ORCID](https://orcid.org/0009-0004-4694-3159))

- Hugo Vasconcelos <hugo.vasconcelos@ufpe.br>
  ([ORCID](https://orcid.org/0000-0001-6249-0920))

- Carlos Amorim <carlos.agaf@ufpe.br>
  ([ORCID](https://orcid.org/0000-0001-6315-8305))

- Diogo Bezerra <diogo.bezerra@ufpe.br>
  ([ORCID](https://orcid.org/0000-0002-1216-8674))
