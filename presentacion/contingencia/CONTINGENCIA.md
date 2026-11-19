# Contingencia de presentación

- Si un nodo no responde, no simular resultados. Mostrar el último estado real documentado y ejecutar diagnóstico.
- Si falta laptop MongoDB, explicar que el replica set está degradado y evitar apagar otro miembro.
- Si MariaDB replica con retraso, no promover; mostrar GTID y `Seconds_Behind_Master`.
- Si una prueba de escritura falla, conservar el error sin secretos y continuar con consultas de solo lectura.
- No desactivar firewall, autenticación ni `read_only` para “hacer funcionar” la demostración.

