# Guía de datos para Frontend y UX/UI

Frontend no debe conectarse directamente a MariaDB. Los siguientes datos se obtienen mediante contratos que el equipo acuerde con Backend/APIcore. Los nombres SQL son referencia de origen, no obligan el nombre de los campos JSON.

## Dashboard

- Emociones recientes: fecha, hora, categoría, emoción específica, intensidad 1–10 y contexto opcional.
- Próximas tomas: medicamento, hora prevista, estado y horario.
- Próximas citas: fecha/hora, profesional, área, ubicación y estado.
- Recordatorios: tipo, contenido, fecha/hora y estado.
- Resúmenes: total de seguimientos, emoción frecuente e intensidad promedio; pueden ser `0`, lista vacía o `null` sin registros.

## Seguimiento emocional

Selectores dependientes: central → media → específica. Cada opción contiene identificador y nombre; la interfaz no debe permitir una combinación de ramas distintas. La intensidad es un selector numérico de 1 a 10 independiente de la emoción. Fecha y hora son obligatorias; contexto es opcional. La clasificación definitiva de emociones está pendiente de Product Manager y UX/UI.

## Historial emocional

Campos: identificador, fecha, hora, central, media, específica, intensidad, color opcional y contexto opcional. Filtros: periodo, emoción e intervalo de intensidad. Orden predeterminado: más reciente primero. La edición/eliminación debe esperar la política de historial acordada.

## Reportes emocionales

Datos disponibles: total, frecuencias absolutas, porcentajes, intensidad promedio, distribución por categoría y series diaria/semanal/mensual. Un periodo vacío debe mostrarse como “sin registros”, no como diagnóstico ni como cero clínico. Las gráficas no deben inferir estados de salud.

## Medicamentos y tratamientos

| Campo | Tipo | Regla de interfaz |
|---|---|---|
| nombre | texto | Obligatorio, máximo 100. |
| compuesto | opción | Obligatorio. |
| cantidad | entero positivo | Obligatorio. |
| unidad_medida | texto/opción | Opcional hasta que se acuerde catálogo. |
| dosis | opción | Obligatoria; se muestra como texto, no se calcula. |
| tratamiento | texto | Opcional. |
| fecha_inicio / fecha_fin | fecha | Fin no anterior al inicio. |
| horarios | lista de horas | Al menos uno en el flujo nuevo; permite varios. |
| recomendaciones / advertencias | texto | Opcionales. |
| estado | opción | Catálogo proporcionado por Backend. |

## Checklist de medicamentos

Cada fila contiene medicamento, fecha/hora prevista, estado (`pendiente`, `tomada`, `omitida`, `cancelada`), hora efectiva opcional y observaciones. Solo una toma pendiente puede confirmarse u omitirse. La interfaz nunca marca automáticamente “tomada” al llegar la hora. Las canceladas se conservan en historial.

## Citas médicas

Campos obligatorios: fecha/hora, médico, área, ubicación y estado. Descripción opcional. Mostrar especialidades del médico y datos públicos de ubicación. Acciones esperadas: crear, reprogramar y cancelar; la cancelación conserva la cita.

## Médicos y especialistas

Mostrar nombre, apellidos, cédula, área, una o varias especialidades y contacto opcional. La cédula es única. Una especialidad puede marcarse principal, pero la interfaz debe admitir varias cuando Backend exponga el contrato.

## Recordatorios

Campos: tipo (`general`, `medicamento`, `cita`), contenido, fecha/hora y estado. Para medicamento se selecciona un horario del tratamiento; para cita se selecciona una cita del usuario. Canal y estado de entrega no existen todavía.

## Perfil

Disponibles: nombre, apellidos, fecha de nacimiento, teléfonos, correo y ubicación. Correo, nombre, primer apellido, nacimiento y teléfono principal son obligatorios en la base. La contraseña nunca se recupera ni se muestra; solo se envía por un flujo seguro de cambio definido por Backend.

## Validaciones y estados visuales

- Distinguir carga, lista vacía, error de validación, conflicto y falta de autorización.
- No mostrar mensajes SQL ni identificadores internos como explicación al usuario.
- Fechas y horas deben usar la zona horaria acordada con Backend.
- Los ejemplos y prototipos deben usar información sintética.
- La UI debe solicitar confirmación antes de cancelar una cita, horario o toma pendiente.

Ejemplo ficticio de toma: `Medicamento ficticio DB`, programada `2026-01-02 08:00`, confirmada `08:05`, estado `tomada`. No representa una recomendación médica.
