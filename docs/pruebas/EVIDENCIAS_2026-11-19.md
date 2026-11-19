# Evidencias ejecutadas — 2026-11-19

- MongoDB: VPS `PRIMARY` prioridad 2, Windows fijo `SECONDARY` prioridad 1 y laptop `SECONDARY` prioridad 0; todos `health: 1`.
- Documento sintético escrito con mayoría y leído directamente en Windows fijo y laptop.
- Respaldo MongoDB completo con oplog; restauración aislada de cuatro colecciones y un documento, cero fallos.
- MariaDB principal: 11.4.3, `server_id=1`, GTID/binlog activos, 23 tablas híbridas.
- HP: MariaDB 11.8.6, `server_id=2`, `read_only=1`, buffer 128 MiB, 15 conexiones.
- MariaDB: `Slave_IO_Running=Yes`, `Slave_SQL_Running=Yes`, `Seconds_Behind_Master=0`, sin errores; inserción encontrada una vez y eliminación replicada a cero.
- Respaldo MariaDB en `/srv/storage/moodsitto/backups/mariadb`; restauración aislada aprobada con 23 tablas.
- Runners HP protegidos `active` antes y después.
- Fragmentación horizontal: fuente 4, reconstruida 4. Vertical: fuente 2, reconstruida 2.
- Validación estática: PowerShell parseado, Bash `-n`, archivos obligatorios y ausencia de secretos rastreados.

Pendiente de evidencia: prueba completa del asistente con credenciales de aplicación entregadas al backend y copia cifrada externa al HP.
