# Integración técnica

## Estado del backend inspeccionado

La rama `backend-moodsitto` contiene PHP con PDO MySQL y expone registro, login, logout, perfil y recordatorios. `api-citas` añade citas y catálogos al backend PHP. El login de Moodsitto usa Bearer con tokens opacos y requiere `api_tokens` y `login_intentos`. APIcore usa un contrato distinto, descrito en [APIcore y Moodsitto](ARQUITECTURA_APICORE.md).

PHP lee `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS` desde `backend/.env` o las variables del proceso, que tienen prioridad. El paquete proporciona `MONGODB_HOSTS`, `MONGODB_DATABASE`, `MONGODB_REPLICA_SET`, `MONGODB_USER`, `MONGODB_PASSWORD` y `MONGODB_AUTH_SOURCE` para la futura conexión documental.

La aplicación debe construir la URI en memoria y codificar usuario/contraseña; no registrar la URI. Forma lógica:

```text
mongodb://USUARIO:CONTRASEÑA@host1:27017,host2:27017,host3:27017/moodsitto?replicaSet=rsMoodsitto&authSource=moodsitto&retryWrites=true&w=majority
```

PHP necesita `ext-mongodb` y una biblioteca mantenida como `mongodb/mongodb` para operaciones documentales. PDO MySQL no conecta con MongoDB. Validar versiones con el entorno real antes de añadir dependencias.

## Responsabilidades

DB Manager administra servidores, replica set, GTID, permisos, respaldos y parámetros de conexión. Cada proceso que acceda a una base privada necesita red y credenciales propias. El equipo de APIcore y backend define el enlace entre ambos servicios, las rutas y la autorización.

## Módulos

- Implementados en backend observado: registro, login, logout, perfil y recordatorios.
- Citas y catálogos implementados en `api-citas`. Para una instalación Moodsitto, DB Manager aplica [la migración de intentos de login](../mariadb/estructura/03-login-intentos.sql) en el principal y confirma el catálogo de estados y los permisos efectivos. Los médicos y lugares deben cargarse según el entorno.
- Esquema disponible y endpoints pendientes para medicamentos, tomas y notificaciones.
- MongoDB disponible, integración backend pendiente: rueda emocional, registros, historial y resúmenes.

