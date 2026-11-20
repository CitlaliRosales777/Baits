# Estado de criterios de aceptación

| Criterio | Estado | Evidencia o bloqueo |
|---|---|---|
| Comunicación Tailscale | APROBADO | `tailscale status/ping` desde `desktop-smecf2n` a los otros tres candidatos |
| Recursos dimensionados | APROBADO | inventario real de Windows fijo, VPS y HP; laptop pendiente de inventario administrativo |
| MariaDB principal | APROBADO | 11.4.3, GTID/binlog, 23 tablas y catálogos verificados |
| MariaDB réplica y runners HP | APROBADO | IO/SQL `Yes`, retraso 0, inserción/eliminación replicadas y runners activos |
| MongoDB tres miembros | APROBADO | VPS PRIMARY p2, Windows fijo SECONDARY p1, laptop SECONDARY p0; todos health 1 |
| Esquema híbrido | APROBADO | 23 tablas y cuatro colecciones desplegadas |
| Usuarios/permisos | APROBADO | usuarios mínimos app/replicación, autenticación interna y firewalls por Tailscale |
| Fragmentación | APROBADO | horizontal 4/4 y vertical 2/2 reconstruidas |
| Auditoría | APROBADO | tablas/colección y evento sintético replicado |
| Respaldos/restauración | APROBADO | MongoDB 4 colecciones y MariaDB 23 tablas restauradas aisladamente; timers activos |
| Monitoreo | APROBADO | cuatro nodos, MongoDB, MariaDB y los dos runners del HP verificados |
| Demostración | PENDIENTE | guion preparado; requiere infraestructura activa |
| Paquete backend | APROBADO | guía, verificadores y API HTTPS probados realmente |
| Asistente probado | APROBADO | API pública y verificador funcionan sin Tailscale ni credenciales DB |
| API pública backend | APROBADO | API sin frontend; HTTPS, CORS local, registro, login, sesión, perfil y logout verificados; puertos DB cerrados |
| Contratos/incompatibilidades | APROBADO | documentación basada en rama backend observada |

Las filas PENDIENTE no se presentan como infraestructura funcional.

