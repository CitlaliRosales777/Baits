# Auditoría de la base de datos Moodsitto

Fecha de revisión: 3 de noviembre de 2026  
Fuente auditada: `bd-moodsitto.sql` en `main` (`1a5af7c`)  
Motor objetivo: MariaDB

## Alcance y método

Se leyó el script completo, se contrastaron sus nombres con los formularios del frontend y se contabilizaron las sentencias `CREATE TABLE` directamente. El repositorio no contiene APIcore ni otra implementación del modelo; por tanto, no fue posible comparar contratos de backend.

## Inventario real

El archivo original define **20 tablas**, no 18:

| Grupo | Tablas |
|---|---|
| Catálogos y soporte | `location`, `area`, `especialidad`, `estados_clinicos`, `estado`, `compuesto`, `dosis`, `horarios`, `intensidad` |
| Personas y atención | `users`, `doctors`, `diagnosticos`, `citas_medicas`, `medicamento`, `recordatorios` |
| Emociones | `emocion_central`, `emocion_media`, `emocion_especifica`, `emocion_conjunto`, `trackeo_emo` |

Todas tienen clave primaria numérica autoincremental. El modelo original declara 33 claves foráneas y usa tipos compatibles con MariaDB (`INT`, `VARCHAR`, `DATE`, `TIME`, `DATETIME`, `TEXT`, `TINYINT`). No especifica `ENGINE`, por lo que la integridad depende de la configuración por defecto del servidor.

## Hallazgos

| Gravedad | Hallazgo | Riesgo | Corrección aplicada/propuesta |
|---|---|---|---|
| Alta | Casi todas las FK aceptan `NULL`, incluso en diagnósticos, citas, medicamentos y seguimiento. | Registros clínicos huérfanos desde el punto de vista del dominio. | Las relaciones obligatorias son `NOT NULL`; se mantienen opcionales ubicación y cita asociada a un recordatorio. |
| Alta | No hay reglas `ON DELETE`/`ON UPDATE` explícitas. | Comportamiento implícito y difícil de integrar. | `RESTRICT` para información clínica; `SET NULL` solo para ubicación opcional y cita de recordatorio. |
| Alta | `passw` permite cualquier texto. | Riesgo de almacenar contraseñas sin hash. | Se conserva el campo por compatibilidad, se documenta que solo APIcore escribe hashes y se limita el usuario de aplicación. La BD no puede distinguir de forma fiable todos los formatos de hash. |
| Media | Catálogos, correo y cédula carecen de unicidad uniforme. | Duplicados y resultados ambiguos. | Restricciones `UNIQUE` en correo, cédula y nombres/valores de catálogos. |
| Media | Solo existen los índices creados implícitamente por PK, UNIQUE y FK; faltan índices compuestos para flujos de usuario/fecha. | Consultas lentas en dashboard e historial. | Índices por `(id_user, fecha)`, doctor/fecha, estado/fecha y emoción/fecha. |
| Media | `cantidad` acepta cero o negativos; color no valida formato. | Datos inválidos. | `CHECK (cantidad > 0)`, intensidad 1–10 y color hexadecimal. |
| Media | `emocion_conjunto` repite central, media y específica sin asegurar por sí misma que pertenezcan a la misma jerarquía. | Combinaciones lógicamente inconsistentes. | Se exige la terna completa y única. La consistencia entre niveles debe validarla APIcore dentro de una transacción; una futura normalización podría guardar solo `id_emo_espe`. |
| Media | Fechas y campos esenciales (`fecha`, `contenido`) son opcionales. | Operaciones incompletas. | Se vuelven obligatorios en el modelo nuevo donde el dominio lo exige. |
| Baja | Nombres mezclan inglés, español, singular/plural y abreviaturas (`users`, `trackeo_emo`, `id_estadoclini`). | Mayor costo cognitivo. | Se conservan para compatibilidad. APIcore deberá encapsularlos mediante DTO/repositorios; un renombrado requiere versión de contrato. |
| Baja | `documento` no define si guarda contenido, URL o ruta. | Exposición de archivos y acoplamiento al servidor. | Se define como referencia opaca; el archivo debe residir en almacenamiento privado y APIcore controlar acceso. |

## Normalización y redundancias

El esquema está mayormente en tercera forma normal: catálogos, profesionales y jerarquía emocional están separados. Las redundancias principales son:

- `citas_medicas.id_area` puede deducirse de `doctors.id_area`, pero se conserva porque una cita podría registrar el área efectiva en ese momento.
- `diagnosticos.id_area` también conserva contexto histórico.
- `emocion_conjunto` duplica la ruta jerárquica; se conserva exclusivamente por compatibilidad.
- `id_horario` en medicamento modela un solo horario. Si un medicamento requiere varios, se necesitará una tabla puente versionada en una futura migración.

## Seguridad y datos sensibles

Son datos personales o potencialmente médicos: identidad, fecha de nacimiento, teléfonos, domicilio, correo, credenciales, diagnósticos, citas, medicamentos, documentos y seguimiento emocional. Deben aplicarse cifrado en tránsito, respaldos cifrados, mínimos privilegios, auditoría de accesos y retención definida. Los datos de prueba incorporados son ficticios y usan el dominio reservado `.invalid`.

## Compatibilidad

- MariaDB 11.4 ejecutó las migraciones y pruebas correctamente.
- Los campos del registro/login (`name`, `lastname1`, `lastname2`, `date_b`, `phone`, `emer_phone`, `mail`, `passw`) se conservan.
- `bd-moodsitto.sql` permanece sin cambios como referencia histórica.
- `V002` es una migración de base limpia. No debe ejecutarse sobre la base heredada: primero se usa el preflight y se planifica una migración de datos según los valores nulos/duplicados encontrados.

## Diferencias con otras implementaciones

No se encontró APIcore, SQL Server, Durus ni otro esquema en el repositorio. La comparación queda pendiente hasta que el equipo proporcione esos repositorios o contratos.

