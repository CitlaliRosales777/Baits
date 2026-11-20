# Demostración de 10–15 minutos

## Interfaz para la exposición

Desde la laptop, abre `presentacion\INICIAR-PRUEBAS.cmd`. También puedes ejecutar `presentacion\interfaz-pruebas.ps1` con PowerShell.

1. Carga `backend-integracion\.env` o escribe las dos contraseñas de aplicación en los campos ocultos.
2. Presiona **Ejecutar todas las seguras** para revisar la infraestructura sin detener servicios.
3. Ejecuta las dos restauraciones aisladas por separado; la interfaz pedirá confirmación.
4. Exporta el reporte al terminar. Se guarda en `evidencias-locales/`, una carpeta ignorada por Git.

La fila de recuperación comprueba que la topología esté lista, pero no apaga equipos ni promueve réplicas. Una caída real solo se hace cuando el profesor la autorice y el equipo acepte la interrupción.

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

