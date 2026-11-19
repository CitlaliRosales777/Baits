# Replicación MariaDB GTID

1. Verificar versiones compatibles y respaldar configuraciones.
2. Aplicar los archivos de `mariadb/configuracion/` tras sustituir la IP del nodo.
3. Crear usuarios con `mariadb/seguridad/usuarios.sql`, reemplazando variables localmente.
4. Tomar respaldo consistente del principal y restaurarlo en la réplica.
5. Configurar `CHANGE MASTER TO MASTER_HOST='IP_TAILSCALE_PRINCIPAL', MASTER_USER='moodsitto_repl', MASTER_PASSWORD='...', MASTER_USE_GTID=slave_pos;` desde una consola segura; no guardar contraseña en archivos/versionado.
6. Ejecutar `START SLAVE; SHOW ALL SLAVES STATUS\G` y exigir `Slave_IO_Running=Yes`, `Slave_SQL_Running=Yes`, sin errores y retraso aceptable.
7. Probar con datos sintéticos y confirmar en la réplica. Registrar hora y GTID en evidencia privada.

Promoción manual: detener escrituras, esperar que la réplica alcance el GTID, `STOP SLAVE`, habilitar escrituras conscientemente, cambiar el endpoint del backend y reconstruir la topología. Si no puede confirmarse convergencia, no promover sin aceptar posible pérdida.

