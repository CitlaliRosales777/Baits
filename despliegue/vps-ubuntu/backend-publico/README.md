# Backend público de Moodsitto

Esta carpeta publica una copia de `backend-moodsitto` sin exponer MariaDB ni MongoDB a Internet.

- Entrada pública: `https://api.lvltechmx.com`
- Contenedores: PHP-FPM y Nginx interno en `127.0.0.1:18080`
- MariaDB: conexión privada desde el VPS hacia `100.89.172.17:3306`
- MongoDB: no se publica; el backend todavía no tiene rutas documentales

El archivo `.env` del VPS contiene únicamente `DB_PASS`, usa permisos `0600` y no se copia al repositorio. El usuario `moodsitto_api` tiene permisos de lectura y escritura sobre `moodsitto`, sin privilegios administrativos.

Para actualizar la aplicación se copia nuevamente la carpeta `backend/` y `fronted/` de la rama `backend-moodsitto`, se ejecuta `docker compose build --pull api` y después `docker compose up -d`.

