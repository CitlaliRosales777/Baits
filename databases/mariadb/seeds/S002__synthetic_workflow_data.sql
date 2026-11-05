-- Flujo ficticio completo. Ningún nombre, contacto o dato tiene valor real o clínico.
USE moodsitto;

INSERT INTO location (calle, colonia, num_ext, cp, descripcion)
VALUES ('Avenida Demostración', 'Colonia Sintética', '100', '00000', 'Ubicación ficticia');
SET @seed_location = LAST_INSERT_ID();

INSERT INTO users
    (name, lastname1, lastname2, date_b, phone, emer_phone, mail, passw, id_location)
VALUES
    ('Usuario', 'Demostración', 'DB', '1990-01-01', '0000000000', NULL,
     'usuario-db@moodsitto.invalid', '$2b$12$hash.ficticio.no.utilizable', @seed_location);
SET @seed_user = LAST_INSERT_ID();

SET @seed_area = (SELECT MIN(id_area) FROM area);
SET @seed_especialidad = (SELECT MIN(id_especialidad) FROM especialidad);
SET @seed_activo = (SELECT id_estado FROM estado WHERE estado = 'Activo');
SET @seed_compuesto = (SELECT MIN(id_compuesto) FROM compuesto);
SET @seed_dosis = (SELECT MIN(id_dosis) FROM dosis);
SET @seed_hora_am = (SELECT id_horario FROM horarios WHERE horario = '08:00:00');
SET @seed_hora_pm = (SELECT id_horario FROM horarios WHERE horario = '20:00:00');
SET @seed_emocion = (SELECT MIN(id_emocion_conjun) FROM emocion_conjunto);
SET @seed_intensidad = (SELECT id_intensidad FROM intensidad WHERE valor = 6);

INSERT INTO doctors
    (id_area, cedula, nombre, apellido_p, apellido_m, num_tel, id_location, id_especialidad)
VALUES
    (@seed_area, 'CEDULA-DEMO-DB-001', 'Profesional', 'Demostración', NULL,
     '0000000001', @seed_location, @seed_especialidad);
SET @seed_doctor = LAST_INSERT_ID();

INSERT INTO doctor_especialidad (id_doctor, id_especialidad, es_principal)
VALUES (@seed_doctor, @seed_especialidad, TRUE);

INSERT INTO medicamento
    (nombre, id_compuesto, cantidad, unidad_medida, id_dosis, id_estado,
     recomendaciones, advertencias, tratamiento, fecha_inicio, fecha_fin,
     id_horario, id_user)
VALUES
    ('Medicamento ficticio DB', @seed_compuesto, 14, 'unidad', @seed_dosis,
     @seed_activo, 'Ejemplo sin indicación médica', 'No consumir',
     'Tratamiento completamente ficticio', '2026-01-01', '2026-01-07',
     @seed_hora_am, @seed_user);
SET @seed_medicamento = LAST_INSERT_ID();

INSERT INTO medicamento_horario
    (id_medicamento, id_user, id_horario, fecha_inicio, fecha_fin, activo, indicaciones)
VALUES
    (@seed_medicamento, @seed_user, @seed_hora_am, '2026-01-01', '2026-01-07', TRUE, 'Ejemplo AM'),
    (@seed_medicamento, @seed_user, @seed_hora_pm, '2026-01-01', '2026-01-07', TRUE, 'Ejemplo PM');
SET @seed_med_hora_pm = LAST_INSERT_ID();
SET @seed_med_hora_am = (
    SELECT id_med_horario FROM medicamento_horario
    WHERE id_medicamento = @seed_medicamento AND id_horario = @seed_hora_am
);

INSERT INTO toma_medicamento
    (id_med_horario, id_user, fecha_hora_programada, fecha_hora_efectiva, estado_toma, observaciones)
VALUES
    (@seed_med_hora_am, @seed_user, '2026-01-02 08:00:00', '2026-01-02 08:05:00', 'tomada', 'Confirmación ficticia'),
    (@seed_med_hora_pm, @seed_user, '2026-01-02 20:00:00', NULL, 'omitida', 'Omisión ficticia'),
    (@seed_med_hora_am, @seed_user, '2026-01-03 08:00:00', NULL, 'pendiente', NULL);

INSERT INTO citas_medicas
    (id_doctor, id_location, id_area, id_estado, fecha, descripcion, id_user)
VALUES
    (@seed_doctor, @seed_location, @seed_area, @seed_activo,
     '2026-02-01 10:00:00', 'Cita ficticia de prueba', @seed_user);
SET @seed_cita = LAST_INSERT_ID();

INSERT INTO recordatorios
    (id_user, id_cita, id_med_horario, tipo, id_horario, contenido, id_estado, fecha)
VALUES
    (@seed_user, NULL, @seed_med_hora_am, 'medicamento', @seed_hora_am,
     'Recordatorio ficticio de medicamento', @seed_activo, '2026-01-03 07:55:00'),
    (@seed_user, @seed_cita, NULL, 'cita', @seed_hora_am,
     'Recordatorio ficticio de cita', @seed_activo, '2026-02-01 09:00:00');

INSERT INTO trackeo_emo
    (fecha, hora, contexto, id_user, id_emo_conjunto, id_intensidad)
VALUES
    ('2026-01-02', '12:00:00', 'Contexto sintético A', @seed_user, @seed_emocion, @seed_intensidad),
    ('2026-01-03', '18:30:00', 'Contexto sintético B', @seed_user, @seed_emocion, @seed_intensidad);
