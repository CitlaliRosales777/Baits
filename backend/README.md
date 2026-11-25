# Backend de Moodsitto

API REST en PHP que atiende al frontend de Moodsitto (emociones, medicamentos, citas y recordatorios). Responde siempre JSON y no mezcla PHP con HTML: el frontend solo llama a las rutas de abajo. La estructura sigue la de `apicore` que dejó el profe (router, middlewares, controladores, modelos y schemas), pero en PHP y con las tablas del esquema del equipo.

## Qué lleva hasta ahora

- Registro, login con token y logout
- Perfil de usuario (ver, editar, borrar cuenta)
- Recordatorios (crear, listar con filtro por fechas y paginación, editar, marcar como completado, borrar)
- Citas médicas (lo mismo que recordatorios) y los catálogos de médicos, áreas y lugares para el formulario
- Estado del servicio (`/health`)

Emociones y medicamentos todavía no tienen rutas.

## Estructura

```
backend/
├── public/          lo único que ve Internet (index.php y .htaccess)
├── src/
│   ├── arranque.php   carga de clases, configuración y zona horaria
│   ├── core/          Config, Database, Request, Response, Router, Aplicacion
│   ├── middlewares/   Cors, Error y Auth (se ejecutan antes del controlador)
│   ├── routers/       rutas.php: todas las rutas en un solo lugar
│   ├── controllers/   reciben la petición y arman la respuesta
│   ├── schemas/       validan los datos de entrada
│   ├── models/        el único lugar donde hay SQL
│   └── services/      tokens y límite de intentos de login
├── sql/
│   ├── extras.sql            tabla extra para el bloqueo de intentos
│   └── catalogos-prueba.sql  médicos, áreas y lugares de ejemplo (solo para la laptop)
├── tests/           pruebas.ps1 y pruebas-citas.ps1
└── .env.example
```

Cada capa solo habla con la de al lado: los controladores no escriben SQL, los modelos no saben nada de HTTP y los schemas no tocan la base. El recorrido de una petición es:

`index.php` → Cors → Error → (Auth, si la ruta es protegida) → controlador → schema (valida) → modelo (SQL) → respuesta JSON

Para agregar una entidad nueva hacen falta un modelo, un schema, un controlador y sus líneas en `routers/rutas.php`. No hay que tocar el núcleo.

## Rutas

| Método | Ruta | Acceso | Qué hace |
| --- | --- | --- | --- |
| GET | `/health` | público | 200 si la API y la base responden, 503 si no |
| POST | `/users` | público | Registro. Devuelve 201 con `Location` |
| POST | `/auth/login` | público | Recibe `mail` y `passw`, devuelve un token |
| POST | `/auth/logout` | token | Revoca el token que se usó |
| GET | `/users/{id}` | token, solo el propio | Ver perfil |
| PUT | `/users/{id}` | token, solo el propio | Reemplaza el perfil |
| PATCH | `/users/{id}` | token, solo el propio | Cambia solo los campos enviados |
| DELETE | `/users/{id}` | token, solo el propio | Desactiva la cuenta y revoca sus tokens |
| GET | `/recordatorios` | token | Lista los propios (`desde`, `hasta`, `page`, `size`) |
| POST | `/recordatorios` | token | Crea (`contenido`, `fecha`) |
| GET | `/recordatorios/{id}` | token | Ver uno |
| PUT | `/recordatorios/{id}` | token | Reemplaza `contenido` y `fecha` |
| PATCH | `/recordatorios/{id}` | token | Cambia `contenido`, `fecha` o `completado` |
| DELETE | `/recordatorios/{id}` | token | Borra |
| GET | `/citas` | token | Lista las propias (`desde`, `hasta`, `page`, `size`) |
| POST | `/citas` | token | Crea (`id_doctor`, `id_location`, `id_area`, `fecha`, `descripcion` opcional). Empieza `pendiente` |
| GET | `/citas/{id}` | token | Ver una, con el nombre del médico, el área y la dirección |
| PUT | `/citas/{id}` | token | Reemplaza todo; si no mandas `descripcion`, se borra |
| PATCH | `/citas/{id}` | token | Cambia los campos enviados, o `completado` |
| DELETE | `/citas/{id}` | token | Borra (409 si la cita tiene recordatorios) |
| GET | `/doctores` | token | Catálogo de médicos, para el `<select>` de citas |
| GET | `/areas` | token | Catálogo de áreas |
| GET | `/lugares` | token | Catálogo de lugares (direcciones) |

Todas las rutas aceptan `OPTIONS` (204 con la cabecera `Allow`) y las de lectura aceptan `HEAD`.

### Autenticación

El login devuelve un token y el frontend lo manda en cada petición:

```
Authorization: Bearer <token>
```

El token vive 60 minutos (`TOKEN_LIFETIME_MINUTES`). En la base solo se guarda su hash SHA-256 (tabla `api_tokens`), así que aunque alguien vea la base no puede usarlo. Cerrar sesión lo marca como revocado.

### Formato de las respuestas

```json
{"status": "ok", "data": {...}}
{"status": "ok", "data": [...], "meta": {"page": 1, "size": 50, "total": 7}}
{"status": "ok", "ID": 12}
{"status": "ok", "message": "Sesión cerrada"}
{"error": "Token inválido o vencido"}
```

Códigos: 200, 201 (creado), 204 (OPTIONS), 400 (datos inválidos), 401 (sin token o token inválido), 403 (no es tu recurso), 404, 405, 409 (correo repetido), 413 (cuerpo mayor a 20000 bytes), 429 (demasiados intentos de login), 500 y 503.

### Ejemplo

```
POST /users
{"name": "Ana", "lastname1": "López", "date_b": "2000-05-17", "phone": "6641234567",
 "mail": "ana@ejemplo.com", "passw": "Clave-Segura-123"}

POST /auth/login
{"mail": "ana@ejemplo.com", "passw": "Clave-Segura-123"}

POST /citas        (los ids salen de GET /doctores, /lugares y /areas; van como número, no como texto)
{"id_doctor": 1, "id_location": 1, "id_area": 1, "fecha": "2026-12-01 10:30",
 "descripcion": "Primera consulta"}

GET /citas/7  →
{"status": "ok", "data": {"id_cita": 7, "fecha": "2026-12-01 10:30:00", "descripcion": "Primera consulta",
 "doctor": {"id": 1, "nombre": "Laura Méndez Ruiz"}, "area": {"id": 1, "nombre": "Psicología"},
 "lugar": {"id": 1, "direccion": "Av. Ejemplo 100, Centro"}, "estado": "pendiente", "completado": false}}
```

## Configuración

Se copia `.env.example` como `.env` y se llenan los datos de la base. El `.env` está en `.gitignore` y nunca se sube. Si el servidor tiene variables de entorno con los mismos nombres, esas tienen prioridad sobre el archivo.

| Variable | Por defecto | Uso |
| --- | --- | --- |
| `DB_HOST` | `127.0.0.1` | Servidor MySQL |
| `DB_PORT` | `3306` | Puerto |
| `DB_NAME`, `DB_USER`, `DB_PASS` | obligatorias | Datos de la base |
| `APP_TIMEZONE` | `America/Tijuana` | Zona horaria de PHP y de MySQL |
| `CORS_ALLOW_ORIGIN` | `*` | Origen permitido del frontend. Puede ser una lista separada por comas |
| `TOKEN_LIFETIME_MINUTES` | `60` | Vida del token |
| `LOGIN_MAX_ATTEMPTS` | `5` | Intentos fallidos antes de bloquear |
| `LOGIN_BLOCK_MINUTES` | `15` | Minutos de bloqueo |

## Base de datos

Usa el esquema del equipo (`bd-moodsitto.sql` de la rama `db-manager`). Además hace falta una tabla que no está en ese esquema, `login_intentos`, para el bloqueo de intentos. Está en `sql/extras.sql` y se corre una sola vez con una cuenta que pueda crear tablas. La cuenta de la API solo necesita `SELECT`, `INSERT`, `UPDATE` y `DELETE`.

## Cómo correrlo en la laptop

Con el `.env` listo, desde la carpeta del proyecto:

```
php -S localhost:8000 -t backend/public
```

Y en otra terminal:

```
powershell -ExecutionPolicy Bypass -File backend\tests\pruebas.ps1
```

Las pruebas de citas necesitan médicos, áreas y lugares en la base. En la laptop se cargan los de ejemplo una vez (con la misma cuenta que `extras.sql`) y luego se corre:

```
powershell -ExecutionPolicy Bypass -File backend\tests\pruebas-citas.ps1
```

## Seguridad

- Contraseñas con `password_hash` (bcrypt). Nunca salen en ninguna respuesta.
- Todas las consultas son preparadas (PDO), sin concatenar datos del usuario.
- Cada consulta de recordatorios y de citas filtra por el usuario del token. Pedir un recurso de otra persona da 404, para no revelar si existe.
- El mensaje de login es el mismo si el correo no existe o la clave está mal, y se compara contra un hash falso para que tarde igual.
- Los errores internos se guardan en el registro del servidor y al cliente solo le llega "Error interno del servidor".
- Cabeceras `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Content-Security-Policy` y `Cache-Control: no-store` en todas las respuestas.
- Los textos se guardan tal cual llegan. El frontend debe mostrarlos con `textContent`, no con `innerHTML`.
- La IP del bloqueo de intentos es la que ve el servidor (`REMOTE_ADDR`). Si el hosting usa un proxy habrá que revisarlo.

## Pendiente de acordar con el equipo

- Los recordatorios son de tipo `general`. Los tipos `medicamento` y `cita` se agregan cuando existan esas rutas.
- Los estados usados son `pendiente` y `completado` (tabla `estado`).
- Borrar una cuenta es borrado lógico: queda desactivada, con su historial, y el correo no se puede volver a usar.
- Cambiar correo o contraseña no está hecho todavía.
- La zona horaria es America/Tijuana.
- La tabla `login_intentos` hay que avisársela a quien lleva la base de datos.
- Los catálogos `doctors`, `area` y `location` son compartidos y la API solo los lee. Falta decidir quién carga los médicos y lugares reales, y si el usuario podrá agregar los suyos.
