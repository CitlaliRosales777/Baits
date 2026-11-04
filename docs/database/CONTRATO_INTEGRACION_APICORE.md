# Contrato de integración pendiente con APIcore

Fuente inspeccionada: [`xtbt/apicore`](https://github.com/xtbt/apicore), `main` en `923fbe5358ec72882af54bef9e567d0dda5b6374` (30-oct-2026). Este documento separa los contratos existentes de las necesidades de Moodsitto; no inventa rutas nuevas.

## Contrato existente verificado

El repositorio contiene dos implementaciones de demostración:

| Implementación | Rutas observadas | Persistencia |
|---|---|---|
| Python (`http.server` + PyMySQL) | `GET /healthcheck`; `GET/POST /moods`; `GET/PUT/DELETE /moods/{id}` | `apitest.moods`, columnas `MoodId`, `MoodName`, `MoodStatus` |
| PHP (PDO) | `GET /health-check`; `GET/POST /moods`; `PUT/DELETE /moods/{id}` | La misma tabla genérica |

No hay rutas implementadas para registro, login, perfil, emociones jerárquicas, seguimiento, medicamentos, citas, recordatorios o diagnósticos. Tampoco hay autenticación, autorización, sesiones, OpenAPI ni pruebas de contrato. Por ello no existe todavía un contrato consumible por el frontend Moodsitto.

## Incompatibilidades y bloqueadores

- El modelo plano `moods` no equivale a `emocion_central/media/especifica`, `emocion_conjunto` ni `trackeo_emo`.
- APIcore apunta a la base `apitest`, no `moodsitto`, y sus PK usan `MoodId`/`Id`.
- Python y PHP tienen convenciones distintas de healthcheck y de envoltura JSON.
- Las conexiones usan valores administrativos `root/root` en código; deben sustituirse por variables de entorno/secret manager y el rol mínimo.
- PHP permite CORS `*` y refleja el cuerpo recibido en respuestas de depuración. Python retorna `str(exception)`. Ambos comportamientos pueden filtrar datos o detalles internos.
- No se validan propiedad del usuario ni permisos. `BaseModel` construye identificadores SQL desde claves del cuerpo y debe usar listas explícitas de columnas por modelo.
- El repositorio versiona un entorno virtual completo y artefactos compilados; debe reemplazarse por un archivo de dependencias bloqueadas y CI reproducible.

La integración no debe apuntar APIcore al nuevo esquema hasta corregir estos bloqueadores y añadir pruebas sobre una instancia de desarrollo.

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

Las consultas de referencia están en `databases/mariadb/queries/dashboard_history.sql` y usan `?` como marcador. El adaptador real debe usar consultas preparadas según el driver.

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

## Acuerdos pendientes

1. Elegir una implementación mantenida (Python o PHP), su driver y versiones soportadas.
2. Definir DTOs, rutas, códigos de error y paginación para Moodsitto.
3. Algoritmo/parámetros de hash y política de sesión.
4. Zona horaria, formato de fechas y manejo de horario de verano.
5. Estados válidos por entidad; hoy comparten el catálogo `estado`.
6. Borrado lógico/retención para datos clínicos.
7. Almacenamiento y autorización de documentos.
8. Estrategia de concurrencia y reintentos.
9. Asignación final de entidades entre MariaDB y SQL Server.

## Secuencia de integración recomendada

1. Retirar credenciales hardcodeadas y crear configuración segura para `moodsitto_app_role`.
2. Unificar el formato de respuesta/error y desactivar debug/CORS abierto fuera de desarrollo.
3. Implementar primero salud de servicio y salud de BD sin revelar secretos.
4. Añadir modelos/repositorios de usuario y emociones con listas de campos explícitas.
5. Ejecutar pruebas de contrato contra las migraciones de esta rama.
6. Incorporar los demás flujos de la tabla anterior y, finalmente, conectar el frontend.

