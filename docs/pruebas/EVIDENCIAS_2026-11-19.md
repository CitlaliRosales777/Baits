# Evidencias ejecutadas — 2026-11-19

- MongoDB: VPS `PRIMARY`, Windows fijo `SECONDARY`, ambos `health: 1` y mismo `optimeDate`.
- Documento sintético escrito con mayoría y leído directamente en el secundario.
- Respaldo MongoDB completo con oplog; restauración aislada de cuatro colecciones y un documento, cero fallos.
- MariaDB principal: 11.4.3, `server_id=1`, GTID/binlog activos, 23 tablas híbridas.
- HP: MariaDB 11.8.6, `server_id=2`, `read_only=1`, buffer 128 MiB, 15 conexiones.
- Respaldo MariaDB en `/srv/storage/moodsitto/backups/mariadb`; restauración aislada aprobada con 23 tablas.
- Runners HP protegidos `active` antes y después.
- Fragmentación horizontal: fuente 4, reconstruida 4. Vertical: fuente 2, reconstruida 2.
- Validación estática: PowerShell parseado, Bash `-n`, archivos obligatorios y ausencia de secretos rastreados.

Pendiente de evidencia: IO/SQL de réplica MariaDB después del paso interactivo; tercer miembro MongoDB en laptop; prueba completa del asistente desde laptop.
