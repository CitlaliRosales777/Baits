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
| Monitoreo | APROBADO | script ejecutado; detecta correctamente laptop MongoDB pendiente |
| Demostración | PENDIENTE | guion preparado; requiere infraestructura activa |
| APIcore en laptop | APROBADO | registro y sesión de prueba realizados contra la base apicore del principal |
| Tablas de inicio de sesión del backend Moodsitto | APROBADO | el principal permite consultar users, api_tokens y login_intentos |
| Restauración de APIcore | PENDIENTE | el trabajo de respaldo vigente solo exporta moodsitto |
| Caída controlada | PENDIENTE | la recuperación operativa de la mayoría MongoDB fue observada; falta un ensayo controlado con tiempos |
| Paquete backend | APROBADO (estático) | asistentes y verificadores presentes |
| Asistente probado | PENDIENTE | sintaxis aprobada; ejecución desde laptop requiere motores/credenciales finales |
| Contratos/incompatibilidades | APROBADO | documentación basada en rama backend observada |

Las filas PENDIENTE no se presentan como infraestructura funcional.

