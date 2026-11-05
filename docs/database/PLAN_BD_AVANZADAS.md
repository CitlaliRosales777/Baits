# Preparación para bases de datos avanzadas

Esta sección documenta compatibilidad y dependencias; no presenta Durus, distribución, APIcore multibase ni infraestructura como implementados.

## Persistencia orientada a objetos

Una futura práctica Durus puede representar `Usuario` como raíz alcanzable, con colecciones de `EventoEmocional`, `Tratamiento`, `Horario` y `Toma`. La identidad relacional se conservaría como referencia de correlación, no como FK entre motores. Herencia/polimorfismo podrían demostrarse con tipos de evento, sin almacenar datos reales.

Durus no ofrece ODL/OQL nativos. Las clases son una analogía de definición y las comprensiones/recorridos Python una analogía de consulta; no deben etiquetarse como implementación de los estándares. Pendiente: versión aprobada, clases, `commit/abort`, reapertura, concurrencia y evidencia.

## Fragmentación vertical y horizontal

`databases/mariadb/advanced/fragmentation_demo.sql` contiene vistas locales con fines didácticos:

- vertical: identidad y contacto de `users`, reconstruidos por `id_user`;
- horizontal: seguimiento reciente y archivo, reconstruidos con `UNION ALL`.

Las vistas no distribuyen datos. Para nodos reales se deben definir claves globales, ubicación de fragmentos, reconstrucción, autorización y comportamiento ante caída. Spider o FederatedX solo se habilitarán en infraestructura de desarrollo después de confirmar soporte del servidor; este repositorio no instala plugins.

## Sistema multibase MariaDB/SQL Server

Diseño propuesto:

| Componente | Responsabilidad futura |
|---|---|
| MariaDB | Identidad, emociones, tratamientos, tomas, citas y recordatorios. |
| SQL Server | Fuente autónoma académica para información clínica sintética. |
| APIcore | Autorización, composición, idempotencia, reintentos y errores parciales. |

`databases/sqlserver/migrations/V001__clinical_node.sql` es un esquema propuesto, no ejecutado. `maria_user_id` sería una referencia lógica: no existe FK entre SGBD. Las consultas globales se componen en la capa de servicio; no se presupone un `JOIN` distribuido ni transacción atómica.

Para actualizaciones en ambas fuentes se requiere saga: validar, escribir con clave de idempotencia, registrar estado, reintentar y compensar. Deben probarse caída/recuperación de cada motor y respuestas parciales antes de declarar la integración operativa.

## Estado

- Implementado: vistas didácticas locales y esquema SQL Server propuesto.
- Verificado: únicamente el modelo MariaDB y sus pruebas.
- Pendiente: Durus, ODL/OQL equivalente, nodos MariaDB, Spider/FederatedX, SQL Server real, APIcore multibase y evidencias de fallos.
- Bloqueado: ejecución distribuida por falta de infraestructura y autorización fuera del rol DB Manager.
