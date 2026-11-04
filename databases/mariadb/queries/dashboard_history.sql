-- Consultas previstas para APIcore. Use parámetros enlazados; no concatene entradas.

-- Historial emocional de un usuario entre dos fechas.
SELECT
    te.id_trackeo,
    te.fecha,
    te.hora,
    te.contexto,
    ec.nombre AS emocion_central,
    em.nombre AS emocion_media,
    ee.nombre AS emocion_especifica,
    i.valor AS intensidad,
    i.color
FROM trackeo_emo te
JOIN emocion_conjunto eco ON eco.id_emocion_conjun = te.id_emo_conjunto
JOIN emocion_central ec ON ec.id_emo_cen = eco.id_emo_cen
JOIN emocion_media em ON em.id_emo_media = eco.id_emo_media
JOIN emocion_especifica ee ON ee.id_emo_espe = eco.id_emo_espe
JOIN intensidad i ON i.id_intensidad = ee.id_intensidad
WHERE te.id_user = ? AND te.fecha BETWEEN ? AND ?
ORDER BY te.fecha DESC, te.hora DESC;

-- Próximas citas del usuario.
SELECT
    c.id_cita,
    c.fecha,
    c.descripcion,
    d.nombre AS doctor_nombre,
    d.apellido_p AS doctor_apellido,
    a.nombre_area,
    e.estado
FROM citas_medicas c
JOIN doctors d ON d.id_doctor = c.id_doctor
JOIN area a ON a.id_area = c.id_area
JOIN estado e ON e.id_estado = c.id_estado
WHERE c.id_user = ? AND c.fecha >= ?
ORDER BY c.fecha;

-- Medicamentos activos y recordatorios próximos.
SELECT
    m.id_medicamento,
    m.nombre,
    m.cantidad,
    ds.dosis,
    h.horario,
    m.recomendaciones,
    m.advertencias
FROM medicamento m
JOIN dosis ds ON ds.id_dosis = m.id_dosis
JOIN horarios h ON h.id_horario = m.id_horario
JOIN estado e ON e.id_estado = m.id_estado
WHERE m.id_user = ? AND e.estado = 'Activo'
ORDER BY h.horario, m.nombre;

