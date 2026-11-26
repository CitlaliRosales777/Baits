# APIcore y Moodsitto en Baits

El flujo acordado por el equipo es:

```text
Cliente o frontend
       |
       v
    APIcore
       |
       v
Backend Moodsitto
       |
       +-- MariaDB
       +-- MongoDB
```

El flujo anterior es el objetivo de integración. En `api-citas`, APIcore incluye implementaciones PHP y Python con conexión SQL propia. El cliente de esa rama envía solicitudes al contrato de APIcore en `localhost:8000`. El backend de Moodsitto ofrece sus propias rutas y conexión SQL. La conexión APIcore → backend queda por definir y probar con el equipo responsable.

| Componente | Contrato observado |
|---|---|
| Cliente de `api-citas` | Envía `Username` y `Password` al login y lee el campo `sub` de un JWT. |
| APIcore PHP/Python | Usa la base `apicore`, con `users.UserId`, `users_tokens` y `moods`. Lee `DB_PASSWORD` y `JWT_SECRET`. |
| Backend PHP Moodsitto | Usa la base `moodsitto`, con `users.id_user` y `api_tokens`. Lee `DB_PASS`, espera `mail` y `passw` en login y usa tokens opacos. |

Cada componente que abra una conexión SQL necesita su propia configuración y cuenta autorizada. Para ejecutar APIcore como viene en la rama, su esquema y su cuenta deben aprovisionarse por separado en el entorno elegido. El equipo debe acordar qué servicio autentica, cómo se valida el token y cómo se resuelve la correspondencia entre `UserId` e `id_user`. Mantén separados los almacenes de identidad hasta definir esa correspondencia.

## Quién necesita Tailscale

Cada host que abra una conexión directa a las bases privadas de DB Manager necesita acceso Tailscale autorizado. El navegador usa la URL HTTP de su API. Si APIcore usa una base aislada en otro entorno, aplica la política de red de ese entorno.

Si un compañero ejecuta el backend directamente en su computadora, esa computadora sí necesita Tailscale. Publicar los puertos 3306 o 27017 para evitarlo no es una opción segura y contradice la infraestructura solicitada.

## Entrega de DB Manager

### Preparar la base de APIcore

1. En el principal de MariaDB, aplica [04-esquema-apicore.sql](../mariadb/estructura/04-esquema-apicore.sql) con la cuenta de migraciones. Está pensado para una instalación nueva y se puede volver a ejecutar. Para una base existente, revisa primero sus columnas e índices. Si corresponde a la versión anterior al registro de contacto, revisa `apicore/migrations/001_users_contacto.sql` de `api-citas`.
2. Crea `apicore_app` para el origen privado del host de APIcore con una contraseña propia. Otorga `SELECT, INSERT, UPDATE, DELETE` exclusivamente sobre `apicore.*`. Ejecuta [verificar-apicore.sql](../mariadb/estructura/verificar-apicore.sql) conectado como esa cuenta a `apicore`. Su salida confirma el contrato de lectura.
3. En el checkout de `api-citas`, copia [apicore.env.example](apicore.env.example) como `apicore/api/v1/php/.env` o `apicore/api/v1/py/.env`, según la implementación elegida. Usa la contraseña entregada por DB Manager en `DB_PASSWORD` y una clave de firma propia del entorno de APIcore en `JWT_SECRET`. El responsable de APIcore gestiona esa clave.

El esquema crea `users`, `users_tokens`, `moods` y `example` vacías. El responsable de APIcore debe provisionar las cuentas iniciales y cargar los catálogos requeridos por su entorno. El volcado de referencia incluye borrados y cuentas de demostración, así que úsalo exclusivamente para un laboratorio descartable.

### Conexión del backend Moodsitto

- Direcciones privadas y nombres de las bases.
- Usuario MariaDB `moodsitto_app` con permisos de aplicación.
- Usuario MongoDB `moodsitto_app` con rol limitado a `moodsitto`.
- Plantilla `.env.example` sin secretos.
- Asistente para crear un `.env` local protegido.
- Prueba automática de autenticación, lectura y escritura sintética.
- Contrato de tablas, colecciones y relación por `id_user`.

Las credenciales de `moodsitto` se entregan por un canal privado al responsable del backend. APIcore debe usar sus propias credenciales SQL cuando se ejecute con su esquema de referencia.

## Responsabilidad del equipo backend/APIcore

El equipo de APIcore y backend define el adaptador, la autenticación entre servicios y la autorización por `id_user`. DB Manager entrega esquemas, cuentas y parámetros de conexión. La comparación por rama está en [Arquitectura de DB Manager](../docs/arquitectura/ARQUITECTURA.md).

