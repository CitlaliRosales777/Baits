-- Recordatorios pendientes, vencidos y clasificados. No implementa su entrega.
USE moodsitto;

-- Pendientes por usuario.
SELECT r.id_recordatorio, r.tipo, r.contenido, r.fecha, r.id_cita,
       r.id_med_horario, e.estado
FROM recordatorios r JOIN estado e ON e.id_estado = r.id_estado
WHERE r.id_user = ? AND r.fecha >= CURRENT_TIMESTAMP AND e.estado = 'Activo'
ORDER BY r.fecha;

-- Vencidos todavía activos.
SELECT r.id_recordatorio, r.tipo, r.contenido, r.fecha
FROM recordatorios r JOIN estado e ON e.id_estado = r.id_estado
WHERE r.id_user = ? AND r.fecha < CURRENT_TIMESTAMP AND e.estado = 'Activo'
ORDER BY r.fecha DESC;

-- Recordatorios de medicamento.
SELECT r.id_recordatorio, r.contenido, r.fecha, m.nombre, h.horario
FROM recordatorios r
JOIN medicamento_horario mh ON mh.id_med_horario = r.id_med_horario
JOIN medicamento m ON m.id_medicamento = mh.id_medicamento
JOIN horarios h ON h.id_horario = mh.id_horario
WHERE r.id_user = ? AND r.tipo = 'medicamento'
ORDER BY r.fecha;

-- Recordatorios de cita.
SELECT r.id_recordatorio, r.contenido, r.fecha, c.fecha AS fecha_cita,
       d.nombre AS doctor_nombre, d.apellido_p AS doctor_apellido
FROM recordatorios r
JOIN citas_medicas c ON c.id_cita = r.id_cita
JOIN doctors d ON d.id_doctor = c.id_doctor
WHERE r.id_user = ? AND r.tipo = 'cita'
ORDER BY r.fecha;
