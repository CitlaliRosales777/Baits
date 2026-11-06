# Moodsitto en Docker

Levanta tres contenedores con un solo comando:
- web: nginx. Muestra el frontend (carpeta fronted/) y manda /api/ a la API.
- api: la API en PHP (carpeta backend/).
- db: MariaDB con las tablas users y location.

El frontend y la API salen de la misma direccion (http://localhost:8080), por eso no hace falta CORS.

## Como usarlo
1. Instalar Docker Desktop y dejarlo en "Engine running".
2. Entrar a la carpeta docker/.
3. Copiar .env.example a .env y cambiar las dos contrasenas por valores aleatorios de 20 o mas caracteres. El archivo .env nunca se sube a Git.
4. Encender: docker compose up -d --build
5. Abrir http://localhost:8080
6. Apagar: docker compose down
7. Apagar y borrar los datos de prueba: docker compose down -v

## Seguridad aplicada
- La API se conecta con el usuario moodsitto_api, que solo tiene SELECT, INSERT, UPDATE y DELETE sobre moodsitto_backend_dev. Nunca usa root.
- La base de datos no publica su puerto hacia afuera. Solo la API puede hablar con ella.
- El servidor web solo escucha en 127.0.0.1:8080.
- Las contrasenas viven en docker/.env, que esta ignorado por Git.
- PHP no muestra errores ni su version al cliente.

## Pendiente
- Conectar los formularios de fronted/ con /api/register y /api/login (hoy main.js solo muestra un mensaje de demostracion).
- Rutas de emociones, medicamentos y citas.
- Migrar al modelo completo de databases/mariadb (feature/db-manager).