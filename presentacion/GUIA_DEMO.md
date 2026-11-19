# Demostración de 10–15 minutos

1. Ejecutar `presentacion\preflight\preflight.ps1` desde la laptop.
2. Mostrar Tailscale y los cuatro nodos sin revelar cuentas ni direcciones públicas.
3. Consultar `SHOW MASTER STATUS` en Windows fijo y `SHOW ALL SLAVES STATUS\G` en HP.
4. Insertar un evento SQL sintético con un UUID y comprobarlo en HP. Eliminarlo al terminar.
5. Mostrar `rs.status()` con VPS PRIMARY, Windows fijo SECONDARY y laptop SECONDARY prioridad 0.
6. Insertar un documento sintético con `writeConcern: majority` y leerlo desde un secundario.
7. Ejecutar `laboratorio/reconstruccion/validar.sql` para mostrar `UNION ALL` y `JOIN`.
8. Mostrar usuarios y grants sin contraseñas: `SHOW GRANTS` y roles MongoDB.
9. Mostrar los timers y el último respaldo; no abrir archivos que contengan datos o hashes de credenciales.
10. Mostrar la evidencia de restauración aislada y el monitoreo.

La caída controlada solo se demuestra con autorización en el momento. MongoDB requiere dos de tres votos. MariaDB no tiene failover automático: se detienen escrituras, se verifica GTID y se promueve manualmente. Si la laptop está apagada, los dos miembros restantes conservan mayoría únicamente si ambos están disponibles.

