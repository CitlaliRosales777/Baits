# Moodsitto en Docker

Levanta tres contenedores con un solo comando:
- web: nginx. Muestra el frontend (carpeta fronted/) y manda /api/ a la API.
- api: la API en PHP (carpeta backend/).
- db: MariaDB 11.4 con el esquema del equipo.

El frontend y la API salen de la misma direccion (http://localhost:8080), por eso no hace falta CORS.

## Como usarlo
1. Instalar Docker Desktop y dejarlo en "Engine running".
2. Entrar a la carpeta docker/.
3. Copiar .env.example a .env y cambiar las dos contrasenas por valores aleatorios de 20 o mas caracteres. El archivo .env nunca se sube a Git.
4. Encender: docker compose up -d --build
5. Abrir http://localhost:8080
6. Apagar: docker compose down
7. Apagar y borrar los datos de prueba: docker compose down -v

## Base de datos
- docker/db/01-schema.sql es una copia de bd-moodsitto.sql de la rama db-manager (commit b6d8cad). Si esa rama cambia, hay que volver a copiarla.
- docker/db/02-catalogos.sql siembra los estados pendiente y completado (solo para pruebas).
- docker/db/03-permisos.sh deja al usuario de la API solo con SELECT, INSERT, UPDATE y DELETE sobre moodsitto.
- Los scripts de esa carpeta solo corren cuando la base se crea desde cero (despues de docker compose down -v).

## Probar con otra carpeta de frontend
Por defecto se sirve ../fronted. Para servir otra carpeta (por ejemplo la rama Front-Dev descargada aparte), antes de encender:
$env:FRONT_DIR = "C:\ruta\a\la\carpeta\fronted"

## Seguridad aplicada
- La API se conecta con el usuario moodsitto_api, que solo tiene SELECT, INSERT, UPDATE y DELETE sobre moodsitto. Nunca usa root.
- La base de datos no publica su puerto hacia afuera. Solo la API puede hablar con ella.
- El servidor web solo escucha en 127.0.0.1:8080.
- Las contrasenas viven en docker/.env, que esta ignorado por Git.
- PHP no muestra errores ni su version al cliente.