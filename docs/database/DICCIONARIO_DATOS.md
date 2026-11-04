# Diccionario de datos

El modelo final tiene 23 tablas de dominio y `schema_migrations`. Usa InnoDB, `utf8mb4`, identificadores `INT UNSIGNED AUTO_INCREMENT` salvo la toma (`BIGINT`), y restricciones explícitas. `NN`, `UK` y `FK` significan no nulo, único y clave foránea.

## Catálogos

| Tabla | Campos y reglas |
|---|---|
| `location` | `id_location` PK; calle y colonia NN; número exterior/interior, CP y descripción opcionales. |
| `area` | `id_area` PK; `nombre_area VARCHAR(100)` NN UK; descripción opcional. |
| `especialidad` | `id_especialidad` PK; nombre NN UK; descripción opcional. |
| `estados_clinicos` | `id_estadoclini` PK; estado NN UK; descripción opcional. |
| `estado` | `id_estado` PK; estado NN UK; descripción opcional. |
| `compuesto` | `id_compuesto` PK; compuesto y vía de administración NN; UK conjunta; descripción opcional. |
| `dosis` | `id_dosis` PK; dosis NN UK; descripción opcional. No se interpreta numéricamente. |
| `horarios` | `id_horario` PK; hora NN UK; descripción opcional. |
| `intensidad` | `id_intensidad` PK; valor NN UK entre 1–10; color hexadecimal y descripción opcionales. |

## Usuarios y atención

| Tabla | Campos y reglas |
|---|---|
| `users` | PK `id_user`; nombre, primer apellido, nacimiento, teléfono, correo UK y hash NN; segundo apellido, emergencia y ubicación opcionales. |
| `doctors` | PK; área, cédula UK, nombre, primer apellido y especialidad heredada NN; segundo apellido, teléfono y ubicación opcionales. |
| `doctor_especialidad` | PK compuesta doctor/especialidad; `es_principal BOOLEAN` NN. Permite varias especialidades. |
| `diagnosticos` | PK; nombre, fecha, área, estado clínico, usuario, doctor y estado NN; descripción y referencia de documento opcionales. |
| `citas_medicas` | PK; doctor, ubicación, área, estado, fecha/hora y usuario NN; descripción opcional. Índices usuario/fecha, doctor/fecha y estado/fecha. |

## Medicamentos

| Tabla | Campos y reglas |
|---|---|
| `medicamento` | PK; nombre, compuesto, cantidad positiva, dosis, estado, horario legado y usuario NN. Unidad, textos y fechas opcionales; fin ≥ inicio. |
| `medicamento_horario` | PK `id_med_horario`; medicamento/usuario, hora y fecha inicial NN; fin e indicaciones opcionales; activo NN; UK medicamento/hora/inicio. FK compuesta garantiza propietario. |
| `toma_medicamento` | PK `id_toma BIGINT`; horario/usuario, instante programado y estado NN; instante efectivo/observaciones opcionales. Estados: pendiente, tomada, omitida, cancelada. UK horario/instante. Tomada exige instante efectivo; otros estados lo prohíben. |

## Recordatorios

`recordatorios`: PK; usuario, tipo, horario, contenido, estado y fecha NN. Cita y horario de medicamento son opcionales. Tipo permitido: general, medicamento o cita. La aplicación valida la correspondencia contextual.

## Emociones

| Tabla | Campos y reglas |
|---|---|
| `emocion_central` | PK; nombre NN UK, intensidad FK NN y descripción opcional. |
| `emocion_media` | PK; nombre, intensidad y central NN; UK por central/nombre y clave candidata media/central. |
| `emocion_especifica` | PK; nombre, intensidad y media NN; UK por media/nombre y clave candidata específica/media. |
| `emocion_conjunto` | PK; central, media y específica NN; UK de terna. FK compuestas impiden mezclar ramas. |
| `trackeo_emo` | PK; fecha, hora, usuario, conjunto e intensidad seleccionada NN; contexto opcional. Índices por usuario/tiempo, emoción/fecha e intensidad/fecha. |

La intensidad de las tablas de catálogo describe la clasificación configurada; `trackeo_emo.id_intensidad` registra la selección del usuario en cada evento y es la única usada para promedios.

## Tabla técnica

`schema_migrations`: `version VARCHAR(20)` PK, descripción y `applied_at TIMESTAMP`. Registra orden básico; no reemplaza bloqueo ni coordinación de una herramienta de migraciones productiva.
