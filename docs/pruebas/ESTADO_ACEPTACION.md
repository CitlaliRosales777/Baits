# Estado de criterios de aceptación

| Criterio | Estado | Evidencia o bloqueo |
|---|---|---|
| Comunicación Tailscale | APROBADO | `tailscale status/ping` desde `desktop-smecf2n` a los otros tres candidatos |
| Recursos dimensionados | APROBADO | inventario real de Windows fijo, VPS y HP; laptop pendiente de inventario administrativo |
| MariaDB principal | APROBADO | 11.4.3, GTID/binlog, 23 tablas y catálogos verificados |
| MariaDB réplica y runners HP | PENDIENTE | 11.8.6 instalada, seed GTID cargado y runners activos; falta `CHANGE MASTER` interactivo |
| MongoDB tres miembros | PENDIENTE | VPS PRIMARY y Windows fijo SECONDARY aprobados; laptop aún no instalada |
| Esquema híbrido | APROBADO | 23 tablas y cuatro colecciones desplegadas |
| Usuarios/permisos | APROBADO parcial | usuarios app/replicación y autenticación MongoDB; réplica SQL pendiente |
| Fragmentación | APROBADO | horizontal 4/4 y vertical 2/2 reconstruidas |
| Auditoría | APROBADO | tablas/colección y evento sintético replicado |
| Respaldos/restauración | APROBADO | MongoDB 4 colecciones y MariaDB 23 tablas restauradas aisladamente; timers activos |
| Monitoreo | APROBADO | script ejecutado; detecta correctamente laptop MongoDB pendiente |
| Demostración | PENDIENTE | guion preparado; requiere infraestructura activa |
| Paquete backend | APROBADO (estático) | asistentes y verificadores presentes |
| Asistente probado | PENDIENTE | sintaxis aprobada; ejecución desde laptop requiere motores/credenciales finales |
| Contratos/incompatibilidades | APROBADO | documentación basada en rama backend observada |

Las filas PENDIENTE no se presentan como infraestructura funcional.

