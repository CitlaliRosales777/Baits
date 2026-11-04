-- Medicamentos, horarios y checklist. Todos los SELECT se restringen por id_user.
USE moodsitto;

-- Medicamentos activos con todos sus horarios vigentes.
SELECT m.id_medicamento, m.nombre, m.cantidad, m.unidad_medida, d.dosis,
       m.tratamiento, m.fecha_inicio, m.fecha_fin, h.horario,
       mh.id_med_horario, mh.indicaciones
FROM medicamento m
JOIN dosis d ON d.id_dosis = m.id_dosis
JOIN medicamento_horario mh ON mh.id_medicamento = m.id_medicamento
JOIN horarios h ON h.id_horario = mh.id_horario
JOIN estado e ON e.id_estado = m.id_estado
WHERE m.id_user = ? AND e.estado = 'Activo' AND mh.activo = TRUE
  AND (mh.fecha_fin IS NULL OR mh.fecha_fin >= CURRENT_DATE)
ORDER BY m.nombre, h.horario;

-- Tratamientos finalizados.
SELECT id_medicamento, nombre, tratamiento, fecha_inicio, fecha_fin
FROM medicamento
WHERE id_user = ? AND fecha_fin IS NOT NULL AND fecha_fin < CURRENT_DATE
ORDER BY fecha_fin DESC;

-- Próximos horarios del día (plantilla; Backend materializa toma_medicamento).
SELECT mh.id_med_horario, m.nombre, h.horario
FROM medicamento_horario mh
JOIN medicamento m ON m.id_medicamento = mh.id_medicamento
JOIN horarios h ON h.id_horario = mh.id_horario
WHERE mh.id_user = ? AND mh.activo = TRUE
  AND CURRENT_DATE BETWEEN mh.fecha_inicio AND COALESCE(mh.fecha_fin, '9999-12-31')
ORDER BY h.horario;

-- Checklist de un día.
SELECT tm.id_toma, m.nombre, tm.fecha_hora_programada, tm.fecha_hora_efectiva,
       tm.estado_toma, tm.observaciones
FROM toma_medicamento tm
JOIN medicamento_horario mh ON mh.id_med_horario = tm.id_med_horario
JOIN medicamento m ON m.id_medicamento = mh.id_medicamento
WHERE tm.id_user = ? AND DATE(tm.fecha_hora_programada) = ?
ORDER BY tm.fecha_hora_programada;

-- Historial de tomas por periodo.
SELECT tm.id_toma, m.nombre, tm.fecha_hora_programada, tm.fecha_hora_efectiva,
       tm.estado_toma
FROM toma_medicamento tm
JOIN medicamento_horario mh ON mh.id_med_horario = tm.id_med_horario
JOIN medicamento m ON m.id_medicamento = mh.id_medicamento
WHERE tm.id_user = ? AND DATE(tm.fecha_hora_programada) BETWEEN ? AND ?
ORDER BY tm.fecha_hora_programada DESC;

-- Cumplimiento: solo tomadas y omitidas forman el denominador; pendientes/canceladas no.
SELECT
    SUM(estado_toma = 'tomada') AS confirmadas,
    SUM(estado_toma = 'omitida') AS omitidas,
    SUM(estado_toma = 'pendiente') AS pendientes,
    ROUND(100 * SUM(estado_toma = 'tomada') /
          NULLIF(SUM(estado_toma IN ('tomada', 'omitida')), 0), 2) AS cumplimiento_porcentaje
FROM toma_medicamento
WHERE id_user = ? AND DATE(fecha_hora_programada) BETWEEN ? AND ?;

-- Confirmar una toma pendiente. La aplicación debe comprobar una fila afectada.
UPDATE toma_medicamento
SET estado_toma = 'tomada', fecha_hora_efectiva = CURRENT_TIMESTAMP
WHERE id_toma = ? AND id_user = ? AND estado_toma = 'pendiente';

-- Marcar omisión; nunca se infiere una toma por el paso del tiempo.
UPDATE toma_medicamento
SET estado_toma = 'omitida', fecha_hora_efectiva = NULL
WHERE id_toma = ? AND id_user = ? AND estado_toma = 'pendiente';
