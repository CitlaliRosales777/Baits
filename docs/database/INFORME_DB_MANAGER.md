# Informe DB Manager — Moodsitto

Fecha: 3 de noviembre de 2026  
Rama: `feature/db-manager`  
Base auditada: `main` en `1a5af7c`

## 1. Resumen ejecutivo

Se auditó el único esquema del repositorio, se preservó intacto y se creó una implementación MariaDB versionada para instalaciones limpias. El nuevo modelo conserva los nombres esperados por el frontend, endurece integridad, agrega índices, semillas sintéticas, consultas de integración y pruebas aisladas. MariaDB 11.4 ejecutó exitosamente dos migraciones, 20 tablas de dominio, 33 FK y 13 comprobaciones CRUD/integridad.

Los diseños para Durus, fragmentación y SQL Server están preparados, pero no se marcan como ejecutados porque faltan esos entornos y APIcore.

## 2. Estado inicial

El repositorio Baits contenía dos commits, un frontend estático sin backend y `bd-moodsitto.sql`. El script original define 20 tablas, no 18. No había migraciones, semillas, pruebas, roles, respaldo documentado ni scripts de bases avanzadas. El APIcore está en un repositorio separado y se proporcionó durante el trabajo.

## 3. Problemas identificados

Los principales fueron FK de dominio opcionales, ausencia de políticas de borrado, catálogos sin unicidad, pocos índices de flujo, cantidades inválidas posibles, nomenclatura mixta, redundancia de jerarquía emocional y falta de política verificable para hashes/documentos. El detalle y gravedad están en `AUDITORIA_BD.md`.

## 4. Archivos creados y modificados

- `databases/mariadb/`: migraciones, semilla, consultas, preflight, roles, fragmentación y pruebas.
- `databases/sqlserver/`: nodo clínico propuesto e instrucciones.
- `databases/durus/`: prototipo de objetos persistentes e instrucciones.
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

Resultado: PASS para instalación limpia, InnoDB, 20 tablas, 33 FK, creación de seis flujos, lectura con JOIN, actualización, borrado controlado, rechazo de FK inválida, correo duplicado, cantidad cero y borrado de usuario referenciado; la transacción CRUD se revirtió. La salida está en `evidencias/mariadb-test-2026-11-03.txt`.

También se revisó Baits en busca de secretos. En los scripts aparecen nombres de campos/inputs de contraseña, marcadores, una variable efímera y un hash ficticio no utilizable; no se incorporaron credenciales reales. La documentación sí registra, como hallazgo de seguridad, las credenciales administrativas hardcodeadas observadas en el repositorio externo APIcore, sin copiar archivos de configuración ni otros valores.

## 8. Limitaciones

- APIcore se inspeccionó estáticamente, pero no se modificó ni se ejecutó integrado con Moodsitto.
- No hubo base heredada con datos para probar actualización in-place.
- No se ejecutaron pruebas multisesión de concurrencia.
- No estaban disponibles SQL Server, SSMS, VPS/nodos MariaDB ni Durus instalado.
- No se probaron Spider/FederatedX ni fallos reales de red.
- El catálogo compartido `estado` necesita reglas por entidad en APIcore.

## 9. Integraciones pendientes

El APIcore inspeccionado (`xtbt/apicore@923fbe5`) solo implementa un CRUD de demostración para `apitest.moods`; no es compatible todavía con el modelo Moodsitto. Debe elegir su implementación definitiva, retirar `root/root`, normalizar respuestas, eliminar fugas de debug, añadir autenticación/autorización y acordar DTOs/rutas, hashing, zona horaria, paginación, estados, documentos, borrado lógico, concurrencia y estrategia multibase. Debe usar consultas preparadas con listas explícitas de columnas y `moodsitto_app_role`, nunca `root`.

Para bases avanzadas quedan pendientes: ejecutar Durus, desplegar nodos de fragmentación, crear SQL Server, implementar composición/idempotencia en APIcore y capturar evidencias reales de caída/recuperación. No se asume una transacción distribuida atómica.

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
2. Proporcionar APIcore y fijar el contrato antes de cambiar nombres o entidades.
3. Definir retención/borrado lógico y cumplimiento para datos de salud.
4. Agregar pruebas de concurrencia e idempotencia.
5. Validar restauraciones periódicas y medir RPO/RTO.
6. Ejecutar la fase multibase solo en infraestructura de desarrollo con datos sintéticos.

