# Contrato e integración con APIcore

Fuente original inspeccionada: [`xtbt/apicore`](https://github.com/xtbt/apicore), `main` en `923fbe5358ec72882af54bef9e567d0dda5b6374` (30-oct-2026). La adaptación funcional vive en `backend/apicore/` dentro de Baits para versionar el contrato junto con el esquema y sus pruebas.

## Implementación Moodsitto en Baits

Se eligió Python con Flask, PyMySQL, bcrypt y tokens HMAC expirables. La implementación se conecta a `moodsitto` exclusivamente mediante variables de entorno y una cuenta DML de mínimos privilegios. No contiene credenciales ni usa `root`.

Rutas implementadas:

- salud de servicio/BD;
- registro, login y perfil;
- catálogos y profesionales;
- catálogo y seguimiento emocional;
- CRUD de medicamentos, citas y recordatorios;
- lectura de diagnósticos;
- dashboard compuesto.

Todas las operaciones privadas obtienen `id_user` del token firmado. Las consultas parametrizan valores y los identificadores variables proceden únicamente de mapas internos. La prueba E2E construye el contenedor, aplica las migraciones/semillas, crea un usuario SQL de permisos mínimos y recorre todos los flujos.

## Contrato original verificado

El repositorio contiene dos implementaciones de demostración:

| Implementación | Rutas observadas | Persistencia |
|---|---|---|
| Python (`http.server` + PyMySQL) | `GET /healthcheck`; `GET/POST /moods`; `GET/PUT/DELETE /moods/{id}` | `apitest.moods`, columnas `MoodId`, `MoodName`, `MoodStatus` |
| PHP (PDO) | `GET /health-check`; `GET/POST /moods`; `PUT/DELETE /moods/{id}` | La misma tabla genérica |

En el repositorio externo original no hay rutas para registro, login, perfil, emociones jerárquicas, seguimiento, medicamentos, citas, recordatorios o diagnósticos. Tampoco hay autenticación, autorización, sesiones, OpenAPI ni pruebas de contrato. Esas carencias se resolvieron mediante la adaptación interna, sin copiar el entorno virtual ni las credenciales del prototipo.

## Incompatibilidades y bloqueadores

- El modelo plano `moods` no equivale a `emocion_central/media/especifica`, `emocion_conjunto` ni `trackeo_emo`.
- APIcore apunta a la base `apitest`, no `moodsitto`, y sus PK usan `MoodId`/`Id`.
- Python y PHP tienen convenciones distintas de healthcheck y de envoltura JSON.
- Las conexiones usan valores administrativos `root/root` en código; deben sustituirse por variables de entorno/secret manager y el rol mínimo.
- PHP permite CORS `*` y refleja el cuerpo recibido en respuestas de depuración. Python retorna `str(exception)`. Ambos comportamientos pueden filtrar datos o detalles internos.
- No se validan propiedad del usuario ni permisos. `BaseModel` construye identificadores SQL desde claves del cuerpo y debe usar listas explícitas de columnas por modelo.
- El repositorio versiona un entorno virtual completo y artefactos compilados; debe reemplazarse por un archivo de dependencias bloqueadas y CI reproducible.

Por estos bloqueadores no se conectó el prototipo externo directamente. La implementación interna reemplaza credenciales hardcodeadas, restringe CORS por configuración, normaliza errores, valida propiedad del usuario y se prueba contra una instancia aislada.

## Capacidades por flujo

| Flujo | Entidades/campos de entrada | Lecturas y validaciones |
|---|---|---|
| Registro | `users`: nombres, `date_b`, teléfonos, `mail`; contraseña solo en tránsito hacia APIcore | Normalizar correo, comprobar UK, validar fecha/teléfonos, generar hash adaptativo; nunca registrar contraseña en logs. |
| Inicio de sesión | `mail` + contraseña recibida por APIcore | Leer `id_user`, `mail`, `passw`; comparar hash en tiempo constante y devolver identidad autorizada, nunca el hash. |
| Perfil | `users`, opcional `location` | Proyectar solo campos permitidos; actualización parcial con validación y autorización del propio usuario. |
| Dashboard | `recordatorios`, `citas_medicas`, `medicamento`, `trackeo_emo` | Consultas limitadas por `id_user`, fecha y estado; paginación y zona horaria acordada. |
| Emociones | catálogos de emoción, `intensidad`, `emocion_conjunto`, `trackeo_emo` | Validar que la terna pertenece a una jerarquía coherente; crear seguimiento en transacción. |
| Medicamentos | `medicamento`, `compuesto`, `dosis`, `horarios`, `estado` | Cantidad positiva, catálogos existentes y propiedad del usuario. No generar recomendaciones clínicas. |
| Citas | `citas_medicas`, `doctors`, `area`, `location`, `estado` | Profesional/área/ubicación válidos, fecha y zona horaria; filtrar siempre por usuario autorizado. |
| Recordatorios | `recordatorios`, opcional `citas_medicas`, `horarios`, `estado` | La cita asociada debe pertenecer al mismo usuario; fecha coherente y contenido limitado. |
| Historial emocional | `trackeo_emo` + jerarquía emocional | Filtro por usuario/rango, orden descendente y paginación. |

Las consultas de referencia están en `databases/mariadb/queries/dashboard_history.sql`. APIcore usa los marcadores `%s` de PyMySQL y nunca concatena valores recibidos del cliente.

## Operaciones y permisos

- APIcore necesita `SELECT`, `INSERT`, `UPDATE` y `DELETE` sobre `moodsitto.*`, concedidos mediante `moodsitto_app_role`.
- No necesita `CREATE`, `ALTER`, `DROP`, `GRANT`, acceso a otras bases ni cuenta `root`.
- Migraciones usan una identidad separada y efímera.
- Las consultas siempre incluyen el `id_user` derivado de la sesión/autorización, nunca uno confiado directamente desde el cliente sin verificar.

## Reglas transaccionales

- Registro: unicidad de correo y escritura de perfil en una transacción.
- Seguimiento emocional: validar la jerarquía y crear `trackeo_emo` en la misma transacción.
- Cita + recordatorio: confirmar ambas escrituras o revertir ambas si la funcionalidad exige atomicidad local.
- No hay transacción distribuida atómica con SQL Server; las operaciones multibase deberán usar idempotencia, compensación y estados observables.

## Campos que no deben exponerse

`users.passw`, credenciales de conexión, detalles internos de documentos, errores SQL, rutas del servidor y datos de otros usuarios. `diagnosticos.documento` debe resolverse a través de autorización y almacenamiento privado.

## Pendientes antes de producción

1. Acordar formalmente DTOs y versionarlos mediante OpenAPI.
2. Incorporar revocación/refresh de tokens y rate limiting para autenticación.
3. Definir zona horaria y manejo de horario de verano.
4. Definir estados válidos por entidad; hoy comparten el catálogo `estado`.
5. Incorporar borrado lógico/retención para datos clínicos.
6. Definir almacenamiento y autorización de documentos.
7. Agregar roles profesionales antes de permitir escritura de diagnósticos.
8. Definir estrategia de concurrencia, idempotencia y reintentos.
9. Asignar definitivamente entidades entre MariaDB y SQL Server.

## Estado de la secuencia de integración

1. Completado: configuración segura y cuenta DML sin `root`.
2. Completado: formato uniforme, errores genéricos y CORS configurable.
3. Completado: salud de servicio/BD sin exponer secretos.
4. Completado: usuarios, emociones y propiedad por usuario.
5. Completado: prueba integral contra migraciones reales.
6. Completado: medicamentos, citas, recordatorios, diagnósticos y dashboard.
7. Pendiente: conectar el frontend y ejecutar pruebas de interfaz.

