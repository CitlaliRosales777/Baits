-- Citas, médicos y especialidades. Usar transacciones para operaciones compuestas.
USE moodsitto;

-- Próximas citas por usuario.
SELECT c.id_cita, c.fecha, c.descripcion, e.estado,
       d.id_doctor, d.nombre, d.apellido_p, a.nombre_area,
       l.calle, l.colonia, l.num_ext
FROM citas_medicas c
JOIN doctors d ON d.id_doctor = c.id_doctor
JOIN area a ON a.id_area = c.id_area
JOIN location l ON l.id_location = c.id_location
JOIN estado e ON e.id_estado = c.id_estado
WHERE c.id_user = ? AND c.fecha >= CURRENT_TIMESTAMP AND e.estado <> 'Cancelado'
ORDER BY c.fecha;

-- Historial por usuario, periodo y estado opcional.
SELECT c.id_cita, c.fecha, c.descripcion, e.estado, d.nombre, d.apellido_p
FROM citas_medicas c
JOIN doctors d ON d.id_doctor = c.id_doctor
JOIN estado e ON e.id_estado = c.id_estado
WHERE c.id_user = ? AND DATE(c.fecha) BETWEEN ? AND ?
  AND (? IS NULL OR c.id_estado = ?)
ORDER BY c.fecha DESC;

-- Citas por médico y periodo.
SELECT c.id_cita, c.id_user, c.fecha, c.descripcion, e.estado
FROM citas_medicas c JOIN estado e ON e.id_estado = c.id_estado
WHERE c.id_doctor = ? AND DATE(c.fecha) BETWEEN ? AND ?
ORDER BY c.fecha;

-- Alta de cita.
INSERT INTO citas_medicas
    (id_doctor, id_location, id_area, id_estado, fecha, descripcion, id_user)
VALUES (?, ?, ?, ?, ?, ?, ?);

-- Modificación autorizada por usuario.
UPDATE citas_medicas
SET id_doctor = ?, id_location = ?, id_area = ?, fecha = ?, descripcion = ?
WHERE id_cita = ? AND id_user = ?;

-- Cancelación lógica: id_estado debe corresponder al catálogo Cancelado.
UPDATE citas_medicas
SET id_estado = ?
WHERE id_cita = ? AND id_user = ?;

-- Directorio de médicos con especialidades múltiples.
SELECT d.id_doctor, d.cedula, d.nombre, d.apellido_p, d.apellido_m,
       d.num_tel, a.nombre_area,
       GROUP_CONCAT(e.especialidad ORDER BY de.es_principal DESC, e.especialidad
                    SEPARATOR ', ') AS especialidades
FROM doctors d
JOIN area a ON a.id_area = d.id_area
JOIN doctor_especialidad de ON de.id_doctor = d.id_doctor
JOIN especialidad e ON e.id_especialidad = de.id_especialidad
WHERE (? IS NULL OR de.id_especialidad = ?)
GROUP BY d.id_doctor, d.cedula, d.nombre, d.apellido_p, d.apellido_m,
         d.num_tel, a.nombre_area
ORDER BY d.apellido_p, d.nombre;
