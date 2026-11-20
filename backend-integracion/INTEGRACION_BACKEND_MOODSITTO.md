# Integración técnica

## Estado del backend inspeccionado

La rama `backend-moodsitto` contiene PHP con PDO MySQL. Implementa registro, login, logout, perfil y CRUD de recordatorios. Emociones, citas y medicamentos están pendientes. No se modificó esa rama.

Variables compatibles: `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS`. Se añade `DB_PORT`. Para MongoDB se proporcionan `MONGODB_HOSTS`, `MONGODB_DATABASE`, `MONGODB_REPLICA_SET`, `MONGODB_USER`, `MONGODB_PASSWORD` y `MONGODB_AUTH_SOURCE`.

La aplicación debe construir la URI en memoria y codificar usuario/contraseña; no registrar la URI. Forma lógica:

```text
mongodb://USUARIO:CONTRASEÑA@host1:27017,host2:27017,host3:27017/moodsitto?replicaSet=rsMoodsitto&authSource=moodsitto&retryWrites=true&w=majority
```

PHP necesita `ext-mongodb` y una biblioteca mantenida como `mongodb/mongodb` para operaciones documentales. PDO MySQL no conecta con MongoDB. Validar versiones con el entorno real antes de añadir dependencias.

## Responsabilidades

DB Manager administra servidores, replica set, GTID, permisos, firewalls, respaldos, restauraciones y parámetros de conexión. APIcore permanece antes del backend y administra el contrato de entrada que defina su equipo. Backend administra endpoints, autorización por `id_user`, validación de entrada, idempotencia y manejo de errores parciales. APIcore y frontend nunca se conectan directamente a ningún motor ni reciben contraseñas DB.

Solo el host donde corre el backend necesita acceso Tailscale. Los integrantes que trabajen únicamente con APIcore o frontend consumen los endpoints acordados por sus equipos.

## Módulos

- Implementados en backend observado: registro, login, logout, perfil y recordatorios.
- Esquema disponible, endpoints pendientes: citas, medicamentos, tomas y notificaciones.
- MongoDB disponible, integración backend pendiente: rueda emocional, registros, historial y resúmenes.

