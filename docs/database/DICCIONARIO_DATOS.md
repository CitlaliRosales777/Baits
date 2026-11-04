# Diccionario de datos

Todos los identificadores son `INT UNSIGNED AUTO_INCREMENT`. Todas las tablas usan InnoDB, `utf8mb4` y la intercalación de la base. `PK`, `FK`, `UK` y `NN` significan clave primaria, foránea, única y no nulo.

## Catálogos y soporte

| Tabla | Propósito | Campos relevantes y reglas |
|---|---|---|
| `location` | Dirección reutilizable. | `calle VARCHAR(100) NN`, `colonia VARCHAR(50) NN`, `num_ext`, `num_int`, `cp`, `descripcion`; el resto es opcional. |
| `area` | Área de atención. | `nombre_area VARCHAR(100) NN UK`, `descripcion`. |
| `especialidad` | Especialidad profesional. | `especialidad VARCHAR(50) NN UK`, `descripcion`. |
| `estados_clinicos` | Estado de evaluación diagnóstica. | `estado_c VARCHAR(50) NN UK`, `descripcion`. |
| `estado` | Estado operativo compartido. | `estado VARCHAR(50) NN UK`, `descripcion`. APIcore debe validar qué valores aplican a cada entidad. |
| `compuesto` | Compuesto de un medicamento. | `compuesto VARCHAR(100) NN`, `via_admin VARCHAR(100)`, `descripcion`; UK compuesta por nombre y vía. |
| `dosis` | Texto de dosis. | `dosis VARCHAR(50) NN UK`, `descripcion`. No se usa para cálculo clínico. |
| `horarios` | Hora reutilizable. | `horario TIME NN UK`, `descripcion`. |
| `intensidad` | Escala emocional. | `valor TINYINT UNSIGNED NN UK` entre 1 y 10, `color CHAR(7)` hexadecimal opcional, `descripcion`. |

## Personas y atención

| Tabla | Propósito | Campos relevantes y reglas |
|---|---|---|
| `users` | Cuenta y perfil. | Nombre, primer apellido, nacimiento, teléfono, `mail VARCHAR(254) NN UK`, `passw VARCHAR(255) NN` (hash); ubicación FK opcional. |
| `doctors` | Profesional de atención. | Área FK NN, `cedula VARCHAR(100) NN UK`, nombre y primer apellido NN, especialidad FK NN, teléfono y ubicación opcionales. |
| `diagnosticos` | Diagnóstico emitido. | `nombre`, `fecha` y FK a área, estado clínico, usuario, doctor y estado son NN; descripción/documento opcionales. |
| `citas_medicas` | Cita de usuario con profesional. | FK NN a doctor, ubicación, área, estado y usuario; `fecha DATETIME NN`; descripción opcional. |
| `medicamento` | Medicamento registrado para usuario. | Nombre, compuesto FK, `cantidad > 0`, dosis FK, estado FK, horario FK y usuario FK son NN; textos clínicos opcionales. |
| `recordatorios` | Aviso programado. | Usuario, horario, estado, contenido y fecha son NN; cita FK opcional. |

## Emociones

| Tabla | Propósito | Campos relevantes y reglas |
|---|---|---|
| `emocion_central` | Primer nivel emocional. | Nombre NN UK, intensidad FK NN, descripción opcional. |
| `emocion_media` | Segundo nivel. | Nombre e intensidad NN, central FK NN; UK `(id_emo_cen, nombre)`. |
| `emocion_especifica` | Tercer nivel. | Nombre e intensidad NN, media FK NN; UK `(id_emo_media, nombre)`. |
| `emocion_conjunto` | Terna compatible con el modelo original. | Tres FK NN y UK conjunta. APIcore valida coherencia de la jerarquía. |
| `trackeo_emo` | Evento de seguimiento. | Fecha, hora, usuario FK y conjunto FK son NN; contexto opcional. |

## Tabla técnica

`schema_migrations` registra `version` (PK), descripción y hora de aplicación. No sustituye una herramienta de migraciones concurrente: solo da trazabilidad básica para este repositorio.

## Índices de consulta

Además de PK/UK/FK, existen índices compuestos para diagnóstico por usuario/fecha y doctor/fecha; citas por usuario, doctor o estado con fecha; medicamento por usuario/estado y horario; recordatorio por usuario o estado con fecha; y seguimiento por usuario/fecha/hora o emoción/fecha.

