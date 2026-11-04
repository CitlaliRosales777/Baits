# Contrato de integración pendiente con APIcore

APIcore no está presente en este repositorio. Este documento describe necesidades de datos, no inventa URLs, verbos HTTP ni respuestas. El equipo de APIcore debe acordar y versionar el contrato antes de conectar el frontend.

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

1. Repositorio, lenguaje, driver y versión de APIcore.
2. DTOs, rutas, códigos de error y paginación.
3. Algoritmo/parámetros de hash y política de sesión.
4. Zona horaria, formato de fechas y manejo de horario de verano.
5. Estados válidos por entidad; hoy comparten el catálogo `estado`.
6. Borrado lógico/retención para datos clínicos.
7. Almacenamiento y autorización de documentos.
8. Estrategia de concurrencia y reintentos.
9. Asignación final de entidades entre MariaDB y SQL Server.

