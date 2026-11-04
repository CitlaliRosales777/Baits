USE moodsitto;

CREATE TEMPORARY TABLE test_results (
    test_name VARCHAR(100) PRIMARY KEY,
    result VARCHAR(10) NOT NULL
);

DELIMITER //
CREATE PROCEDURE assert_true(IN condition_value BOOLEAN, IN failure_message VARCHAR(255))
BEGIN
    IF condition_value IS NULL OR condition_value = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = failure_message;
    END IF;
END//

CREATE PROCEDURE expect_duplicate_mail()
BEGIN
    DECLARE duplicate_detected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET duplicate_detected = TRUE;
    INSERT INTO users
        (name, lastname1, date_b, phone, mail, passw)
    VALUES
        ('Duplicado', 'Prueba', '1990-01-01', '0000000000',
         'db-test@moodsitto.invalid', '$2b$12$hash.ficticio.no.utilizable');
    IF duplicate_detected = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: duplicate email accepted';
    END IF;
    INSERT INTO test_results VALUES ('unique email rejected', 'PASS');
END//

CREATE PROCEDURE expect_invalid_fk()
BEGIN
    DECLARE fk_detected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET fk_detected = TRUE;
    INSERT INTO trackeo_emo
        (fecha, hora, contexto, id_user, id_emo_conjunto, id_intensidad)
    VALUES
        ('2026-01-15', '10:00:00', 'Debe fallar', 4294967295, 4294967295,
         @id_intensidad);
    IF fk_detected = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: invalid foreign key accepted';
    END IF;
    INSERT INTO test_results VALUES ('invalid FK rejected', 'PASS');
END//

CREATE PROCEDURE expect_invalid_quantity()
BEGIN
    DECLARE check_detected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET check_detected = TRUE;
    INSERT INTO medicamento
        (nombre, id_compuesto, cantidad, id_dosis, id_estado, id_horario, id_user)
    VALUES
        ('Cantidad inválida', @id_compuesto, 0, @id_dosis, @id_estado,
         @id_horario, @id_user);
    IF check_detected = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: zero quantity accepted';
    END IF;
    INSERT INTO test_results VALUES ('invalid CHECK rejected', 'PASS');
END//

CREATE PROCEDURE expect_null_compound_route()
BEGIN
    DECLARE null_detected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET null_detected = TRUE;
    INSERT INTO compuesto (compuesto, via_admin)
    VALUES ('Compuesto sin vía de prueba', NULL);
    IF null_detected = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: NULL compound route accepted';
    END IF;
    INSERT INTO test_results VALUES ('null compound route rejected', 'PASS');
END//

CREATE PROCEDURE expect_duplicate_compound()
BEGIN
    DECLARE duplicate_detected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET duplicate_detected = TRUE;
    INSERT INTO compuesto (compuesto, descripcion, via_admin)
    VALUES ('Compuesto sintético A', 'Duplicado que debe fallar', 'Oral');
    IF duplicate_detected = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: duplicate compound accepted';
    END IF;
    INSERT INTO test_results VALUES ('duplicate compound rejected', 'PASS');
END//

CREATE PROCEDURE expect_restricted_user_delete()
BEGIN
    DECLARE restricted_detected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET restricted_detected = TRUE;
    DELETE FROM users WHERE id_user = @id_user;
    IF restricted_detected = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: referenced user deleted';
    END IF;
    INSERT INTO test_results VALUES ('referenced delete rejected', 'PASS');
END//

CREATE PROCEDURE expect_duplicate_intake()
BEGIN
    DECLARE duplicate_detected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET duplicate_detected = TRUE;
    INSERT INTO toma_medicamento
        (id_med_horario, id_user, fecha_hora_programada, estado_toma)
    VALUES
        (@id_med_horario_am, @id_user, '2026-02-20 08:00:00', 'pendiente');
    IF duplicate_detected = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: duplicate intake accepted';
    END IF;
    INSERT INTO test_results VALUES ('duplicate intake rejected', 'PASS');
END//

CREATE PROCEDURE expect_invalid_intake_confirmation()
BEGIN
    DECLARE check_detected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET check_detected = TRUE;
    INSERT INTO toma_medicamento
        (id_med_horario, id_user, fecha_hora_programada, estado_toma)
    VALUES
        (@id_med_horario_pm, @id_user, '2026-02-21 20:00:00', 'tomada');
    IF check_detected = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: taken intake without confirmation accepted';
    END IF;
    INSERT INTO test_results VALUES ('invalid intake confirmation rejected', 'PASS');
END//

CREATE PROCEDURE expect_invalid_emotion_hierarchy()
BEGIN
    DECLARE fk_detected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '23000' SET fk_detected = TRUE;
    INSERT INTO emocion_conjunto (id_emo_espe, id_emo_media, id_emo_cen)
    VALUES (@id_emo_espe_original, @id_emo_media_alterna, @id_emo_cen_alterna);
    IF fk_detected = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: invalid emotion hierarchy accepted';
    END IF;
    INSERT INTO test_results VALUES ('invalid emotion hierarchy rejected', 'PASS');
END//
DELIMITER ;

START TRANSACTION;

INSERT INTO location (calle, colonia, num_ext, cp, descripcion)
VALUES ('Calle Ficticia', 'Colonia Prueba', '101', '22000', 'Dirección sintética');
SET @id_location = LAST_INSERT_ID();

INSERT INTO users
    (name, lastname1, lastname2, date_b, phone, emer_phone, mail, passw, id_location)
VALUES
    ('Ada', 'Prueba', 'Sintética', '1995-05-10', '0000000001', '0000000002',
     'db-test@moodsitto.invalid', '$2b$12$hash.ficticio.no.utilizable', @id_location);
SET @id_user = LAST_INSERT_ID();
INSERT INTO test_results VALUES ('CREATE user', 'PASS');

SET @id_area = (SELECT id_area FROM area WHERE nombre_area = 'Psicología');
SET @id_especialidad = (
    SELECT id_especialidad FROM especialidad WHERE especialidad = 'Psicología clínica'
);
SET @id_estado = (SELECT id_estado FROM estado WHERE estado = 'Activo');
SET @id_estadoclini = (
    SELECT id_estadoclini FROM estados_clinicos WHERE estado_c = 'En evaluación'
);
SET @id_compuesto = (
    SELECT id_compuesto FROM compuesto WHERE compuesto = 'Compuesto sintético A'
);
SET @id_dosis = (SELECT id_dosis FROM dosis WHERE dosis = 'Dosis de prueba');
SET @id_horario = (SELECT id_horario FROM horarios WHERE horario = '08:00:00');
SET @id_emocion = (SELECT MIN(id_emocion_conjun) FROM emocion_conjunto);
SET @id_intensidad = (SELECT id_intensidad FROM intensidad WHERE valor = 6);
SET @id_emo_espe_original = (
    SELECT id_emo_espe FROM emocion_conjunto WHERE id_emocion_conjun = @id_emocion
);

INSERT INTO doctors
    (id_area, cedula, nombre, apellido_p, num_tel, id_location, id_especialidad)
VALUES
    (@id_area, 'CEDULA-FICTICIA-001', 'Profesional', 'Prueba', '0000000003',
     @id_location, @id_especialidad);
SET @id_doctor = LAST_INSERT_ID();

INSERT INTO doctor_especialidad (id_doctor, id_especialidad, es_principal)
VALUES (@id_doctor, @id_especialidad, TRUE);
INSERT INTO test_results VALUES ('CREATE doctor specialty', 'PASS');

INSERT INTO citas_medicas
    (id_doctor, id_location, id_area, id_estado, fecha, descripcion, id_user)
VALUES
    (@id_doctor, @id_location, @id_area, @id_estado, '2026-02-20 09:30:00',
     'Cita ficticia', @id_user);
SET @id_cita = LAST_INSERT_ID();
INSERT INTO test_results VALUES ('CREATE appointment', 'PASS');

INSERT INTO medicamento
    (nombre, id_compuesto, cantidad, unidad_medida, id_dosis, id_estado,
     recomendaciones, advertencias, tratamiento, fecha_inicio, fecha_fin,
     id_horario, id_user)
VALUES
    ('Medicamento ficticio', @id_compuesto, 10, 'unidad', @id_dosis, @id_estado,
     'Solo demostración', 'No consumir', 'Plan ficticio', '2026-02-20',
     '2026-03-20', @id_horario, @id_user);
SET @id_medicamento = LAST_INSERT_ID();
INSERT INTO test_results VALUES ('CREATE medication', 'PASS');

INSERT INTO medicamento_horario
    (id_medicamento, id_user, id_horario, fecha_inicio, fecha_fin, activo)
VALUES
    (@id_medicamento, @id_user, @id_horario, '2026-02-20', '2026-03-20', TRUE);
SET @id_med_horario_am = LAST_INSERT_ID();

SET @id_horario_pm = (SELECT id_horario FROM horarios WHERE horario = '20:00:00');
INSERT INTO medicamento_horario
    (id_medicamento, id_user, id_horario, fecha_inicio, fecha_fin, activo)
VALUES
    (@id_medicamento, @id_user, @id_horario_pm, '2026-02-20', '2026-03-20', TRUE);
SET @id_med_horario_pm = LAST_INSERT_ID();
INSERT INTO test_results VALUES ('CREATE multiple medication schedules', 'PASS');

INSERT INTO toma_medicamento
    (id_med_horario, id_user, fecha_hora_programada, fecha_hora_efectiva,
     estado_toma)
VALUES
    (@id_med_horario_am, @id_user, '2026-02-20 08:00:00',
     '2026-02-20 08:03:00', 'tomada'),
    (@id_med_horario_pm, @id_user, '2026-02-20 20:00:00', NULL, 'omitida'),
    (@id_med_horario_am, @id_user, '2026-02-21 08:00:00', NULL, 'pendiente');
INSERT INTO test_results VALUES ('CREATE medication intake checklist', 'PASS');

INSERT INTO recordatorios
    (id_user, id_cita, id_med_horario, tipo, id_horario, contenido, id_estado, fecha)
VALUES
    (@id_user, @id_cita, NULL, 'cita', @id_horario, 'Recordatorio ficticio', @id_estado,
     '2026-02-20 08:30:00');
SET @id_recordatorio = LAST_INSERT_ID();
INSERT INTO test_results VALUES ('CREATE reminder', 'PASS');

INSERT INTO diagnosticos
    (nombre, descripcion, fecha, id_area, id_estadoclini, id_user, id_doctor, id_estado)
VALUES
    ('Diagnóstico ficticio', 'Sin valor clínico', '2026-02-20', @id_area,
     @id_estadoclini, @id_user, @id_doctor, @id_estado);
SET @id_diagnostico = LAST_INSERT_ID();
INSERT INTO test_results VALUES ('CREATE diagnosis', 'PASS');

INSERT INTO trackeo_emo
    (fecha, hora, contexto, id_user, id_emo_conjunto, id_intensidad)
VALUES
    ('2026-02-20', '10:15:00', 'Seguimiento ficticio', @id_user, @id_emocion,
     @id_intensidad);
SET @id_trackeo = LAST_INSERT_ID();
INSERT INTO test_results VALUES ('CREATE emotion tracking', 'PASS');

SET @join_count = (
    SELECT COUNT(*)
    FROM trackeo_emo te
    JOIN users u ON u.id_user = te.id_user
    JOIN emocion_conjunto ec ON ec.id_emocion_conjun = te.id_emo_conjunto
    JOIN emocion_especifica ee ON ee.id_emo_espe = ec.id_emo_espe
    WHERE te.id_trackeo = @id_trackeo AND u.mail = 'db-test@moodsitto.invalid'
);
CALL assert_true(@join_count = 1, 'FAIL: relational READ/JOIN');
INSERT INTO test_results VALUES ('READ relational JOIN', 'PASS');

SET @cumplimiento = (
    SELECT ROUND(100 * SUM(estado_toma = 'tomada') / NULLIF(
        SUM(estado_toma IN ('tomada', 'omitida')), 0
    ), 2)
    FROM toma_medicamento
    WHERE id_user = @id_user
);
CALL assert_true(@cumplimiento = 50.00, 'FAIL: medication compliance calculation');
INSERT INTO test_results VALUES ('READ medication compliance', 'PASS');

INSERT INTO emocion_central (nombre, descripcion, id_intensidad)
VALUES ('Central alterna de prueba', 'Solo prueba transaccional', @id_intensidad);
SET @id_emo_cen_alterna = LAST_INSERT_ID();
INSERT INTO emocion_media (nombre, descripcion, id_intensidad, id_emo_cen)
VALUES ('Media alterna de prueba', 'Solo prueba transaccional', @id_intensidad,
        @id_emo_cen_alterna);
SET @id_emo_media_alterna = LAST_INSERT_ID();

UPDATE users SET phone = '0000000099' WHERE id_user = @id_user;
CALL assert_true(
    (SELECT phone FROM users WHERE id_user = @id_user) = '0000000099',
    'FAIL: user UPDATE'
);
INSERT INTO test_results VALUES ('UPDATE user', 'PASS');

CALL expect_duplicate_mail();
CALL expect_invalid_fk();
CALL expect_invalid_quantity();
CALL expect_null_compound_route();
CALL expect_duplicate_compound();
CALL expect_restricted_user_delete();
CALL expect_duplicate_intake();
CALL expect_invalid_intake_confirmation();
CALL expect_invalid_emotion_hierarchy();

DELETE FROM recordatorios WHERE id_recordatorio = @id_recordatorio;
CALL assert_true(
    NOT EXISTS (SELECT 1 FROM recordatorios WHERE id_recordatorio = @id_recordatorio),
    'FAIL: controlled reminder DELETE'
);
INSERT INTO test_results VALUES ('DELETE controlled reminder', 'PASS');

SELECT test_name, result FROM test_results ORDER BY test_name;
SELECT 'PASS CRUD/integrity: transaction will be rolled back' AS result;

ROLLBACK;

DROP PROCEDURE expect_duplicate_mail;
DROP PROCEDURE expect_invalid_fk;
DROP PROCEDURE expect_invalid_quantity;
DROP PROCEDURE expect_null_compound_route;
DROP PROCEDURE expect_duplicate_compound;
DROP PROCEDURE expect_restricted_user_delete;
DROP PROCEDURE expect_duplicate_intake;
DROP PROCEDURE expect_invalid_intake_confirmation;
DROP PROCEDURE expect_invalid_emotion_hierarchy;
DROP PROCEDURE assert_true;

