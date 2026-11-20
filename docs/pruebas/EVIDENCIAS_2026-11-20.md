# Evidencias ejecutadas — 2026-11-20

- La copia de `backend-moodsitto` quedó desplegada en contenedores aislados en el VPS, sin modificar la rama de los compañeros.
- `https://api.lvltechmx.com` respondió por HTTPS con healthcheck, registro sintético, login, cookie de sesión, perfil y logout. El frontend no está desplegado.
- Se probó un origen local `http://localhost:5500`: preflight 204, CORS con credenciales y cookie `Secure; SameSite=None`. Un origen externo no autorizado no recibió cabecera CORS.
- El usuario sintético se eliminó después de la prueba.
- La API usa `moodsitto_api` desde `100.94.145.63`, con permisos `SELECT`, `INSERT`, `UPDATE` y `DELETE` sobre `moodsitto`.
- El firewall de Windows permite el puerto 3306 desde la IP Tailscale del VPS, sin abrirlo a otros orígenes.
- Los puertos públicos 3306 y 27017 respondieron como cerrados.
- El certificado Let's Encrypt corresponde a `api.lvltechmx.com`, renueva mediante `certbot.timer` y vence el 18 de febrero de 2027.
- MongoDB permaneció `PRIMARY` en el VPS y con aproximadamente 2.8 GiB de memoria disponible después del despliegue.
- Los runners `tec-2022-transportesjulian` y `tec-2022-municipalos` permanecieron activos en el HP.
- La replicación MariaDB conservó un proceso `Binlog Dump` activo.
- MariaDB se reinició después de confirmar su archivo de configuración y volvió a escuchar en `127.0.0.1` y `100.89.172.17`.
- El verificador público de PowerShell aprobó DNS, Internet, HTTPS y disponibilidad de la API.

Pendiente: rutas backend para emociones, citas y medicamentos, y copia cifrada externa al HP.
