# APIcore para Moodsitto

Adaptación de la implementación Python de [`xtbt/apicore`](https://github.com/xtbt/apicore) al modelo MariaDB de Baits. Vive dentro de este repositorio para que esquema, backend y pruebas evolucionen juntos. No contiene otro directorio `.git`.

## Capacidades implementadas

| Método y ruta | Función | Autenticación |
|---|---|---|
| `GET /healthcheck` | Salud del servicio y conexión MariaDB | No |
| `POST /api/v1/auth/register` | Registro con hash bcrypt | No |
| `POST /api/v1/auth/login` | Inicio de sesión y token HMAC con expiración | No |
| `GET/PATCH /api/v1/profile` | Perfil del usuario | Sí |
| `GET /api/v1/catalogs` | Catálogos y profesionales con ubicación de consulta | No |
| `GET /api/v1/emotions/catalog` | Jerarquía emocional | No |
| `GET/POST /api/v1/emotions/tracking` | Historial y seguimiento emocional | Sí |
| `GET/POST/PATCH/DELETE /api/v1/medications[/id]` | CRUD de medicamentos | Sí |
| `GET/POST/PATCH/DELETE /api/v1/appointments[/id]` | CRUD de citas | Sí |
| `GET/POST/PATCH/DELETE /api/v1/reminders[/id]` | CRUD de recordatorios | Sí |
| `GET /api/v1/diagnoses` | Diagnósticos del usuario | Sí |
| `GET /api/v1/dashboard` | Resumen de citas, recordatorios y emociones | Sí |

Las operaciones autenticadas siempre agregan `id_user` desde el token; no confían en un identificador proporcionado por el cliente. Las consultas usan parámetros y los identificadores SQL dinámicos proceden únicamente de mapas internos.

## Configuración

Copie `.env.example` a un archivo local no versionado o inyecte las variables desde un gestor de secretos. Son obligatorias:

- `MOODSITTO_DB_USER` y `MOODSITTO_DB_PASSWORD`: cuenta con permisos DML mínimos.
- `MOODSITTO_API_SECRET`: al menos 32 caracteres aleatorios.

APIcore nunca debe conectarse como `root`. El archivo `.env` está excluido de Git.

## Ejecución local

```powershell
cd backend\apicore
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:MOODSITTO_DB_USER = 'moodsitto_api'
$env:MOODSITTO_DB_PASSWORD = '<obtener-del-gestor-de-secretos>'
$env:MOODSITTO_API_SECRET = '<valor-aleatorio-de-32-caracteres-o-mas>'
python run.py
```

El servidor escucha en `127.0.0.1:65000` de manera predeterminada. Para una ejecución compartida use el contenedor/Gunicorn y TLS en el proxy inverso.

## Pruebas

Pruebas unitarias:

```powershell
pip install -r requirements-dev.txt
pytest -q
```

Prueba integral aislada (construye APIcore, levanta MariaDB, aplica migraciones/semillas, crea un usuario SQL de mínimos privilegios y recorre todos los flujos):

```powershell
& .\tests\run-integration.ps1
```

Cada ejecución genera secretos y un proyecto Compose únicos; al finalizar elimina contenedores, red y volumen incluso si falla.

## Límites actuales

- Los tokens se invalidan al expirar; todavía no existe revocación anticipada ni refresh token.
- Diagnósticos son de solo lectura para usuarios. Su creación debe quedar restringida a un rol profesional cuando exista autorización por roles.
- Antes de producción se requieren rate limiting, TLS, observabilidad sin datos sensibles y una política formal de retención/borrado clínico.

