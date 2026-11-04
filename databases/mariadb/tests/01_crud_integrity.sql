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
        (fecha, hora, contexto, id_user, id_emo_conjunto)
    VALUES
        ('2026-01-15', '10:00:00', 'Debe fallar', 4294967295, 4294967295);
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

INSERT INTO doctors
    (id_area, cedula, nombre, apellido_p, num_tel, id_location, id_especialidad)
VALUES
    (@id_area, 'CEDULA-FICTICIA-001', 'Profesional', 'Prueba', '0000000003',
     @id_location, @id_especialidad);
SET @id_doctor = LAST_INSERT_ID();

INSERT INTO citas_medicas
    (id_doctor, id_location, id_area, id_estado, fecha, descripcion, id_user)
VALUES
    (@id_doctor, @id_location, @id_area, @id_estado, '2026-02-20 09:30:00',
     'Cita ficticia', @id_user);
SET @id_cita = LAST_INSERT_ID();
INSERT INTO test_results VALUES ('CREATE appointment', 'PASS');

INSERT INTO medicamento
    (nombre, id_compuesto, cantidad, id_dosis, id_estado, recomendaciones,
     advertencias, tratamiento, id_horario, id_user)
VALUES
    ('Medicamento ficticio', @id_compuesto, 10, @id_dosis, @id_estado,
     'Solo demostración', 'No consumir', 'Plan ficticio', @id_horario, @id_user);
SET @id_medicamento = LAST_INSERT_ID();
INSERT INTO test_results VALUES ('CREATE medication', 'PASS');

INSERT INTO recordatorios
    (id_user, id_cita, id_horario, contenido, id_estado, fecha)
VALUES
    (@id_user, @id_cita, @id_horario, 'Recordatorio ficticio', @id_estado,
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
    (fecha, hora, contexto, id_user, id_emo_conjunto)
VALUES
    ('2026-02-20', '10:15:00', 'Seguimiento ficticio', @id_user, @id_emocion);
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
DROP PROCEDURE assert_true;

