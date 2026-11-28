# Contingencia de presentación

- Si un nodo no responde, no simular resultados. Mostrar el último estado real documentado y ejecutar diagnóstico.
- Si falta laptop MongoDB, explicar que el replica set está degradado y evitar apagar otro miembro.
- Si MariaDB replica con retraso, no promover; mostrar GTID y `Seconds_Behind_Master`.
- Antes de promover el HP, verifica que el Windows fijo pueda reincorporarse como réplica. MariaDB requiere una réplica de la misma versión o más reciente que el primario. Comprueba también el endpoint de APIcore y el respaldo de reversión.
- Si una prueba de escritura falla, conservar el error sin secretos y continuar con consultas de solo lectura.
- No desactivar firewall, autenticación ni `read_only` para “hacer funcionar” la demostración.

