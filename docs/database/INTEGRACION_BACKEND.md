# Integración de datos para Backend / APIcore

Este documento describe persistencia y operaciones SQL; no define endpoints. Backend debe usar una cuenta con el rol `moodsitto_app_role`, conexiones cifradas, consultas parametrizadas y `id_user` obtenido de la identidad autenticada.

## Convenciones comunes

- Identificadores: `INT UNSIGNED`; `toma_medicamento.id_toma` usa `BIGINT UNSIGNED`.
- Fechas de calendario: `DATE`; horas: `TIME`; instantes locales: `DATETIME`. El equipo debe acordar una zona horaria.
- Obligatorio significa `NOT NULL`; opcional significa que acepta `NULL`.
- Conflicto de `UNIQUE`: responder como duplicado, no repetir silenciosamente.
- Error de FK: la referencia no existe o pertenece a otro usuario.
- Error de `CHECK`: entrada fuera del dominio permitido.
- Nunca exponer mensajes SQL, nombres de host, consultas o credenciales al cliente.
- Operaciones compuestas deben usar transacción y `ROLLBACK` ante cualquier error.
- Los ejemplos usan datos ficticios y el dominio reservado `.invalid`.

## Autenticación y usuarios

| Elemento | Detalle |
|---|---|
| Tabla | `users`; ubicación opcional en `location`. |
| PK/FK | `users.id_user`; `id_location -> location`. |
| Obligatorios | `name`, `lastname1`, `date_b`, `phone`, `mail`, `passw`. |
| Opcionales | `lastname2`, `emer_phone`, `id_location`. |
| Validaciones | Correo único; `passw` contiene un hash adaptativo producido por Backend, nunca texto plano. |
| CRUD | Crear cuenta, leer perfil propio y actualizar campos autorizados. El borrado físico queda restringido si existe historial. |
| Transacción | Crear ubicación + usuario o actualizar ambos de forma atómica. |

Ejemplo ficticio: `Usuario Demostración`, `usuario-db@moodsitto.invalid`. La base no implementa sesiones, tokens ni recuperación de contraseña.

## Seguimiento e historial emocional

| Elemento | Detalle |
|---|---|
| Tablas | `emocion_central`, `emocion_media`, `emocion_especifica`, `emocion_conjunto`, `intensidad`, `trackeo_emo`. |
| PK/FK | `trackeo_emo.id_trackeo`; FK obligatorias a usuario, conjunto e intensidad. |
| Obligatorios | `fecha`, `hora`, `id_user`, `id_emo_conjunto`, `id_intensidad`. |
| Opcional | `contexto`. |
| Validaciones | Intensidad 1–10; la terna central/media/específica se valida con FK compuestas. |
| CRUD | Registrar, listar y filtrar; modificar/eliminar requiere política acordada porque altera historial. |
| Consultas | `queries/emotional_tracking.sql`. |

Regla: no confiar en una combinación enviada por el cliente. Backend debe listar niveles dependientes o aceptar solo `id_emocion_conjunto` válido. La clasificación emocional de las semillas es demostrativa; Product Manager y UX/UI deben aprobar la definitiva.

## Reportes estadísticos

Las consultas están en `queries/emotional_reports.sql` y sus columnas en `CONSULTAS_REPORTES.md`. Siempre reciben el usuario autorizado y un periodo válido. No promedian identificadores, evitan división entre cero y no generan conclusiones clínicas. Backend puede convertir los resultados a JSON o PDF, pero la base solo entrega datos agregados.

## Medicamentos y tratamientos

| Elemento | Detalle |
|---|---|
| Tablas | `medicamento`, `compuesto`, `dosis`, `estado`, `medicamento_horario`, `horarios`. |
| PK/FK | `medicamento.id_medicamento`; horario enlaza medicamento, usuario y hora. |
| Obligatorios | Nombre, compuesto, cantidad positiva, dosis, estado, horario legado, usuario; cada programación requiere fechas de inicio, usuario y hora. |
| Opcionales | Unidad, recomendaciones, advertencias, tratamiento, fechas del medicamento y fin/indicaciones del horario. |
| Validaciones | Fin no anterior al inicio; programación única por medicamento/hora/inicio; usuario del horario debe coincidir con el dueño del medicamento. |
| CRUD | Alta/edición del tratamiento; activar/cerrar horarios. No borrar horarios con tomas históricas. |
| Consultas | `queries/medications.sql`. |

`medicamento.id_horario` se conserva por compatibilidad histórica. Las nuevas funciones deben usar `medicamento_horario`, que permite múltiples horas sin duplicar el medicamento.

## Confirmación de tomas

| Elemento | Detalle |
|---|---|
| Tabla | `toma_medicamento`. |
| PK/FK | `id_toma`; FK compuesta `(id_med_horario, id_user)` impide cruzar cuentas. |
| Obligatorios | Horario, usuario, fecha/hora programada y estado. |
| Opcionales | Fecha/hora efectiva y observaciones. |
| Estados | `pendiente`, `tomada`, `omitida`, `cancelada`. |
| Validaciones | Una toma por horario e instante; `tomada` exige hora efectiva; los demás estados exigen hora efectiva nula. |
| CRUD | Materializar toma, consultar checklist, confirmar u omitir. Conservar historial. |
| Consultas | Checklist, historial, cumplimiento y transiciones en `queries/medications.sql`. |

Backend debe materializar las tomas de forma idempotente. Llegar al horario no confirma la dosis. Si cambia un tratamiento, se cierra el horario con `fecha_fin/activo`; tomas futuras pueden marcarse `cancelada`, sin borrar las pasadas. El cumplimiento usa solo tomadas + omitidas como denominador; pendientes y canceladas se informan aparte.

## Citas médicas

| Elemento | Detalle |
|---|---|
| Tabla | `citas_medicas`; catálogos `doctors`, `location`, `area`, `estado`. |
| Obligatorios | Doctor, ubicación, área, estado, fecha/hora y usuario. |
| Opcional | Descripción. |
| CRUD | Crear, consultar, modificar y cancelar lógicamente. |
| Restricciones | No borrar físicamente una cita con historial; validar pertenencia del usuario en cada escritura. |
| Consultas | `queries/appointments_doctors.sql`. |

Crear o reprogramar una cita y sus recordatorios debe ejecutarse en una transacción.

## Médicos y especialidades

| Elemento | Detalle |
|---|---|
| Tablas | `doctors`, `doctor_especialidad`, `especialidad`, `area`, `location`. |
| Obligatorios | Área, cédula única, nombre, primer apellido y especialidad principal heredada. |
| Opcionales | Segundo apellido, teléfono y ubicación. |
| Relaciones | `doctor_especialidad` permite varias especialidades; `es_principal` identifica preferencia. |
| CRUD | Registrar/actualizar profesional y asociar especialidades; no borrar si tiene citas o diagnósticos. |

Por compatibilidad, `doctors.id_especialidad` permanece y debe coincidir con una asociación principal. Backend debe actualizar ambas representaciones dentro de la misma transacción.

## Recordatorios

| Elemento | Detalle |
|---|---|
| Tabla | `recordatorios`. |
| Obligatorios | Usuario, tipo, horario, contenido, estado y fecha programada. |
| Opcionales | Cita o horario de medicamento relacionado. |
| Tipos | `general`, `medicamento`, `cita`. |
| Validaciones | Para tipo medicamento se espera `id_med_horario`; para cita se espera `id_cita`. Backend valida esa regla contextual. |
| Consultas | `queries/reminders.sql`. |

La tabla solo persiste la programación. Canal, dispositivo, reintentos, entrega y notificaciones en tiempo real quedan pendientes de Backend/DevOps.

## Diagnósticos y documentos

`diagnosticos` enlaza área, estado clínico, usuario, doctor y estado operativo; `nombre` y `fecha` son obligatorios. `documento` es una referencia opaca a almacenamiento privado, no contenido binario ni URL pública. Toda escritura requiere autorización profesional y transacción si se adjunta metadata de archivo.

## Permisos mínimos

- Migraciones: cuenta separada con DDL, usada solo durante despliegue controlado.
- Aplicación: `SELECT`, `INSERT`, `UPDATE`, `DELETE` sobre `moodsitto.*`; no `CREATE USER`, `GRANT`, DDL ni acceso a otras bases.
- Reportes/QA: rol de solo lectura cuando corresponda.
- Backend no debe conectarse como `root`.

Los roles de referencia están en `databases/mariadb/security/roles.sql`; no contienen usuarios ni contraseñas.

## Pendientes de acuerdo con Backend

- Contratos REST/OpenAPI y nombres de DTO.
- Algoritmo y parámetros del hash de contraseña.
- Zona horaria y serialización de fechas.
- Política de borrado lógico, retención y auditoría.
- Catálogos de estado específicos por entidad.
- Autorización profesional para diagnósticos.
- Manejo de documentos, notificaciones y concurrencia.
