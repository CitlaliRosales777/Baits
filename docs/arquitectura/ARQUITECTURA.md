# Arquitectura objetivo y límites

## Topología

| Nodo | Servicio | Rol |
|---|---|---|
| Windows fijo (por confirmar) | MariaDB | principal de escritura, `server_id=1` |
| HP Ubuntu (`ubuntu-hp`) | MariaDB | réplica GTID, `read_only`, configuración de 3.3 GiB |
| VPS (`lvltechmx`) | MongoDB | miembro preferido, prioridad 2 |
| Windows fijo | MongoDB | secundario elegible, prioridad 1 |
| Laptop Windows | MongoDB | secundario con datos, prioridad 0 |

Toda comunicación usa direcciones Tailscale. Antes de aplicar configuraciones deben sustituirse marcadores y comprobar que cada `bindIp`/`bind-address` corresponde al equipo correcto. No se abre 3306 ni 27017 a Internet.

MariaDB replica de forma asíncrona: puede existir retraso y pérdida de las últimas transacciones si se promueve una réplica desactualizada. La promoción es manual. MongoDB usa `rsMoodsitto` y escrituras importantes con `w: "majority"`; con tres votos requiere dos miembros disponibles. La laptop temporal reduce la disponibilidad cuando está apagada.

## Modelo híbrido

MariaDB conserva identidad, sesiones/tokens, citas, medicamentos, recordatorios y datos relacionales. MongoDB contiene `catalogo_emociones`, `registros_emocionales`, `resumenes_emocionales` y `auditoria_documental`.

`users.id_user` se copia como entero `id_user` en documentos MongoDB. No existe una clave foránea entre motores: el backend debe autenticar al usuario, usar el identificador de la sesión y filtrar siempre por `id_user`. Una operación que cruza motores usa idempotencia y compensación; no se declara transacción distribuida.

## Contrato backend observado

La rama `backend-moodsitto` usa PHP/PDO MySQL, variables `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS`, sesiones HTTP y las tablas `users`, `recordatorios` y `estado`. Implementa registro, login, perfil y recordatorios; emociones, medicamentos y citas están pendientes. No usa MongoDB todavía. El paquete de integración añade variables MongoDB sin modificar esa rama.

## Acceso sencillo para el equipo

Una copia sin modificaciones de la rama backend está desplegada en `https://api.lvltechmx.com`. Nginx termina HTTPS y reenvía a dos contenedores internos en `127.0.0.1:18080`. La API usa `moodsitto_api`, autorizado únicamente desde la IP Tailscale del VPS y con permisos `SELECT`, `INSERT`, `UPDATE` y `DELETE` sobre `moodsitto`.

Los compañeros consumen HTTPS y no necesitan Tailscale ni credenciales de los motores. Los puertos 3306 y 27017 permanecen cerrados a Internet. MongoDB no se expone y seguirá detrás de la API cuando el equipo implemente las rutas emocionales.

