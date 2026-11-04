# Informe DB Manager — Moodsitto

Fecha: 3 de noviembre de 2026  
Rama: `feature/db-manager`  
Base auditada: `main` en `1a5af7c`

## 1. Resumen ejecutivo

Se auditó el único esquema del repositorio, se preservó intacto y se creó una implementación MariaDB versionada para instalaciones limpias. El nuevo modelo conserva los nombres esperados por el frontend, endurece integridad, agrega índices, semillas sintéticas, consultas de integración y pruebas aisladas. MariaDB 11.4 ejecutó exitosamente dos migraciones, 20 tablas de dominio, 33 FK y 15 comprobaciones CRUD/integridad.

Los diseños para fragmentación y SQL Server están preparados, pero no se marcan como ejecutados porque faltan esos entornos. APIcore quedó integrado dentro de `backend/apicore/` y validado contra MariaDB; el prototipo Durus también se ejecutó en un contenedor desechable con Python 3.10.

## 2. Estado inicial

El repositorio Baits contenía dos commits, un frontend estático sin backend y `bd-moodsitto.sql`. El script original define 20 tablas, no 18. No había migraciones, semillas, pruebas, roles, respaldo documentado ni scripts de bases avanzadas. El APIcore está en un repositorio separado y se proporcionó durante el trabajo.

## 3. Problemas identificados

Los principales fueron FK de dominio opcionales, ausencia de políticas de borrado, catálogos sin unicidad, pocos índices de flujo, cantidades inválidas posibles, nomenclatura mixta, redundancia de jerarquía emocional y falta de política verificable para hashes/documentos. El detalle y gravedad están en `AUDITORIA_BD.md`.

## 4. Archivos creados y modificados

- `databases/mariadb/`: migraciones, semilla, consultas, preflight, roles, fragmentación y pruebas.
- `databases/sqlserver/`: nodo clínico propuesto e instrucciones.
- `databases/durus/`: prototipo de objetos persistentes e instrucciones.
- `backend/apicore/`: backend Python integrado, contenedor y pruebas unitarias/E2E.
- `docs/database/`: auditoría, ER, diccionario, decisiones, CRUD, APIcore, bases avanzadas, seguridad, evidencias e informe.
- `.gitignore`: protege secretos locales, respaldos y almacenamiento Durus.

No se modificó el frontend ni `bd-moodsitto.sql`.

## 5. Migraciones

- `V001`: crea la base con `utf8mb4` y el ledger `schema_migrations`.
- `V002`: crea el modelo compatible con 20 tablas, reglas de integridad e índices.

Están destinadas a una base limpia. Para una instalación heredada se añadió un preflight de solo lectura; no se ejecutan `ALTER` destructivos sin conocer los datos reales y disponer de respaldo restaurable.

## 6. Modelo resultante

El modelo mantiene usuarios, profesionales, diagnósticos, citas, medicamentos, recordatorios y tres niveles de emoción. Las relaciones clínicas son obligatorias y restringen borrados; ubicación y cita de recordatorio son opcionales donde el dominio lo permite. El ER y el diccionario contienen cardinalidades, campos e índices.

## 7. Pruebas ejecutadas y resultados

Entorno real: Docker Desktop, imagen `mariadb:11.4`, contenedor/red/volumen aislados y eliminados al terminar.

Resultado: PASS para instalación limpia, InnoDB, 20 tablas, 33 FK, creación de seis flujos, lectura con JOIN, actualización, borrado controlado, rechazo de FK inválida, correo duplicado, compuesto duplicado, vía de administración nula, cantidad cero y borrado de usuario referenciado; la transacción CRUD se revirtió. El preflight comprobó todas las restricciones `NOT NULL`, `UNIQUE` y `CHECK` de V002 sin hallazgos en la instalación limpia. Dos ejecuciones simultáneas también terminaron en PASS con proyectos Compose diferentes. La salida estándar está en `evidencias/mariadb-test-2026-11-03.txt`.

También se revisó Baits en busca de secretos. En los scripts aparecen nombres de campos/inputs de contraseña, marcadores, una variable efímera y un hash ficticio no utilizable; no se incorporaron credenciales reales. La documentación sí registra, como hallazgo de seguridad, las credenciales administrativas hardcodeadas observadas en el repositorio externo APIcore, sin copiar archivos de configuración ni otros valores.

## 8. Limitaciones

- APIcore interno fue validado en contenedores; el repositorio externo original no se modificó porque la cuenta disponible solo tenía lectura.
- No hubo base heredada con datos para probar actualización in-place.
- No se ejecutaron pruebas multisesión de concurrencia.
- No estaban disponibles SQL Server, SSMS ni VPS/nodos MariaDB; Durus solo se validó en un contenedor efímero, no en la infraestructura de demostración.
- No se probaron Spider/FederatedX ni fallos reales de red.
- El catálogo compartido `estado` necesita reglas por entidad en APIcore.

## 9. Integraciones pendientes

El APIcore original (`xtbt/apicore@923fbe5`) solo implementaba un CRUD de demostración para `apitest.moods`. La adaptación interna ya usa `moodsitto`, bcrypt, tokens firmados, consultas parametrizadas, configuración por entorno y permisos mínimos. Antes de producción siguen pendientes OpenAPI, revocación/refresh, rate limiting, zona horaria, estados por entidad, documentos, borrado lógico, concurrencia y estrategia multibase.

Para bases avanzadas quedan pendientes: ampliar Durus con abort/reapertura/concurrencia, desplegar nodos de fragmentación, crear SQL Server, implementar composición/idempotencia en APIcore y capturar evidencias reales de caída/recuperación. No se asume una transacción distribuida atómica.

## 10. Reproducción

Requisitos: Git, Docker Desktop/Engine, Docker Compose v2 y PowerShell.

```powershell
git switch feature/db-manager
& .\databases\mariadb\tests\run-tests.ps1
```

Resultado esperado final:

```text
PASS schema: 20 tables, 33 FKs, 2 migrations, all InnoDB
PASS CRUD/integrity: transaction will be rolled back
PASS: migraciones, datos sintéticos y pruebas SQL completados.
```

Para una base heredada: obtener respaldo, restaurarlo en un entorno aislado, ejecutar `preflight/P001__legacy_read_only_audit.sql` y diseñar una migración específica para los hallazgos. No ejecutar `V002` sobre tablas existentes.

## 11. Recomendaciones

1. Integrar el runner en CI sin secretos persistentes.
2. Versionar el contrato APIcore con OpenAPI antes de cambiar nombres o entidades.
3. Definir retención/borrado lógico y cumplimiento para datos de salud.
4. Agregar pruebas de concurrencia e idempotencia.
5. Validar restauraciones periódicas y medir RPO/RTO.
6. Ejecutar la fase multibase solo en infraestructura de desarrollo con datos sintéticos.

## 12. Entrega a DevOps

La rama `feature/db-manager` se publicó y se abrió el PR [#1](https://github.com/CitlaliRosales777/Baits/pull/1) hacia `main` con el título solicitado. GitGuardian reportó éxito al abrirlo.

No se encontró `.github/CODEOWNERS`, protección clásica para `main` ni rulesets accesibles en el repositorio. Hay colaboradores con permisos de escritura/administración, pero ninguno está identificado explícitamente como responsable DevOps; por ello no se solicitó revisión a una persona al azar. El PR permanece abierto, sin aprobación propia y sin fusionar, a la espera de que el equipo identifique/asigne al revisor responsable.

