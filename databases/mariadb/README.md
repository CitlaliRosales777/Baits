# MariaDB de Moodsitto

Esta carpeta contiene el modelo reproducible. El archivo raíz `bd-moodsitto.sql` se conserva intacto como referencia histórica.

## Estructura

- `migrations/`: migraciones ordenadas para una base limpia.
- `seeds/`: catálogos y jerarquía emocional con datos ficticios.
- `queries/`: consultas parametrizadas previstas para APIcore.
- `tests/`: pruebas automatizadas y runner aislado.
- `preflight/`: consultas de solo lectura para evaluar una base heredada.
- `security/`: roles sin usuarios ni credenciales.

## Prueba automatizada recomendada

Requisitos: Docker Desktop, Docker Compose v2 y PowerShell 7 o Windows PowerShell 5.1.

Desde la raíz del repositorio:

```powershell
& .\databases\mariadb\tests\run-tests.ps1
```

El runner genera una contraseña efímera, crea un proyecto Compose aislado, aplica migraciones y semillas en orden, ejecuta todas las pruebas y elimina contenedor, red y volumen. No publica puertos y no toca una base compartida.

Para trabajo manual copie `.env.example` a `.env`, asigne un secreto local y no confirme ese archivo. El runner automatizado siempre elimina sus recursos efímeros, incluso ante un fallo.

## Base heredada

No aplique `V002` sobre tablas existentes: contiene `CREATE TABLE` y está diseñada para una base limpia. Ejecute primero `preflight/P001__legacy_read_only_audit.sql`, respalde la base y revise duplicados, nulos e inconsistencias. Una migración in-place debe construirse con los resultados reales y validarse en una copia restaurada; el proyecto no realiza correcciones destructivas automáticas.

## Orden manual

Con un cliente MariaDB autenticado y desde esta carpeta:

```text
migrations/V001__create_database.sql
migrations/V002__create_relational_model.sql
seeds/S001__synthetic_reference_data.sql
tests/00_schema_assertions.sql
tests/01_crud_integrity.sql
```

Use siempre una cuenta de migración separada. APIcore debe conectarse con un usuario al que se le haya asignado `moodsitto_app_role`, nunca como `root`.

