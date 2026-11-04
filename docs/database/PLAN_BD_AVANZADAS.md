# Plan de bases de datos avanzadas

Este plan separa lo preparado de lo comprobado. Se validaron MariaDB, APIcore integrado y el prototipo Durus en contenedores desechables. No se dispone de VPS, nodos Spider/FederatedX, SQL Server ni SSMS.

## Unidad 2: objetos persistentes

El prototipo `databases/durus/model.py` representa `UserProfile` y `EmotionEvent` como objetos persistentes. Demuestra:

- herencia desde `Persistent`;
- encapsulamiento mediante constructores y `add_event`;
- persistencia por alcanzabilidad desde el objeto raíz;
- una transacción local mediante `commit()`;
- base para polimorfismo con subclases de eventos.

Durus no ofrece ODL/OQL nativos. La clase Python cumple el papel conceptual de definición del objeto; una comprensión o recorrido Python equivale conceptualmente a una consulta OQL, sin ser una implementación del estándar. Debe declararse esta diferencia durante la demostración.

Comprobado: creación del almacenamiento, objetos sintéticos, `commit()`, lectura y cierre del `FileStorage` sin excepción. Pendiente: fijar una versión aprobada en entorno virtual, cerrar/reabrir en procesos separados, provocar un `abort()` y simular dos conexiones según las capacidades reales de Durus.

## Fragmentación

`databases/mariadb/advanced/fragmentation_demo.sql` implementa vistas locales para explicar:

- fragmentación vertical de `users` en identidad y contacto, reconstruida por `id_user`;
- fragmentación horizontal de `trackeo_emo` en últimos 90 días y archivo, reconstruida con `UNION ALL`.

Las vistas no son distribución física. Para dos nodos MariaDB:

1. Crear nodos de desarrollo con datos ficticios y esquemas compatibles.
2. Elegir Spider o FederatedX después de verificar que el servidor permite el motor/plugin.
3. Mantener una clave global no solapada o asignada por un servicio.
4. Crear tablas remotas y una vista de reconstrucción.
5. Probar caída de cada nodo, latencia, reintentos y resultados parciales.
6. Registrar si las escrituras son locales, remotas o compensadas.

No se afirma consistencia fuerte ni commit atómico entre nodos. Spider/FederatedX debe validarse en la infraestructura exacta; no se habilitan plugins automáticamente desde este repositorio.

## Unidad 3: sistema multibase

Distribución propuesta para la demostración:

| Origen | Responsabilidad autónoma |
|---|---|
| MariaDB | Identidad, catálogos, emociones, citas, medicamentos y recordatorios existentes. |
| SQL Server | Referencias externas y notas clínicas del prototipo en `moodsitto_clinical`. |
| APIcore | Autorización, composición de lecturas, idempotencia, reintentos y errores parciales. |

El script `databases/sqlserver/migrations/V001__clinical_node.sql` prepara el nodo independiente. `maria_user_id` es una referencia lógica; no puede existir una FK entre SGBD. APIcore combinará datos en memoria o mediante una respuesta compuesta, no con un supuesto JOIN distribuido del motor.

## Escenarios de demostración

1. Leer el perfil y emociones desde MariaDB.
2. Insertar/modificar una nota sintética en SQL Server.
3. Combinar perfil + nota en APIcore usando una clave de correlación.
4. Detener MariaDB: las operaciones exclusivamente clínicas pueden continuar si no requieren validar identidad; las demás fallan de forma controlada.
5. Detener SQL Server: perfil/emociones siguen disponibles; el componente clínico se marca temporalmente no disponible.
6. Repetir una escritura tras reconexión con clave de idempotencia y verificar ausencia de duplicados.

No hay transacción distribuida atómica. Para una operación que toca ambos motores se usará una secuencia/saga: validar, escribir con idempotencia, registrar estado, reintentar y compensar cuando proceda.

## Herramientas y evidencias pendientes

- DBeaver: conexiones separadas, metadatos, consultas y planes.
- SSMS: esquema, índices, escrituras y simulación de indisponibilidad SQL Server.
- Logs correlacionados de APIcore sin datos sensibles.
- Capturas reales de nodos, reconstrucción, fallo y recuperación.

Estas evidencias solo se generarán cuando la infraestructura exista; no se fabrican resultados.

