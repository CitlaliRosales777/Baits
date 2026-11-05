-- Extensiones incrementales del DB Manager para horarios, tomas y consistencia emocional.
-- Requiere V001 y V002. No elimina datos ni tablas existentes.
USE moodsitto;

ALTER TABLE medicamento
    ADD COLUMN unidad_medida VARCHAR(30) NULL AFTER cantidad,
    ADD COLUMN fecha_inicio DATE NULL AFTER tratamiento,
    ADD COLUMN fecha_fin DATE NULL AFTER fecha_inicio,
    ADD CONSTRAINT chk_medicamento_fechas
        CHECK (fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio),
    ADD CONSTRAINT uq_medicamento_usuario UNIQUE (id_medicamento, id_user);

CREATE TABLE medicamento_horario (
    id_med_horario INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_medicamento INT UNSIGNED NOT NULL,
    id_user        INT UNSIGNED NOT NULL,
    id_horario     INT UNSIGNED NOT NULL,
    fecha_inicio   DATE NOT NULL,
    fecha_fin      DATE,
    activo         BOOLEAN NOT NULL DEFAULT TRUE,
    indicaciones   TEXT,
    CONSTRAINT chk_med_horario_fechas
        CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT uq_med_horario_programacion
        UNIQUE (id_medicamento, id_horario, fecha_inicio),
    CONSTRAINT uq_med_horario_usuario UNIQUE (id_med_horario, id_user),
    CONSTRAINT fk_med_horario_medicamento_usuario
        FOREIGN KEY (id_medicamento, id_user)
        REFERENCES medicamento(id_medicamento, id_user)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_med_horario_hora
        FOREIGN KEY (id_horario) REFERENCES horarios(id_horario)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    INDEX idx_med_horario_usuario_activo (id_user, activo, fecha_inicio, fecha_fin)
) ENGINE=InnoDB;

-- Conserva y migra el horario único legado como primera programación.
INSERT INTO medicamento_horario
    (id_medicamento, id_user, id_horario, fecha_inicio, fecha_fin, activo, indicaciones)
SELECT
    id_medicamento,
    id_user,
    id_horario,
    COALESCE(fecha_inicio, CURRENT_DATE),
    fecha_fin,
    TRUE,
    recomendaciones
FROM medicamento;

CREATE TABLE toma_medicamento (
    id_toma               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_med_horario        INT UNSIGNED NOT NULL,
    id_user               INT UNSIGNED NOT NULL,
    fecha_hora_programada DATETIME NOT NULL,
    fecha_hora_efectiva   DATETIME,
    estado_toma           VARCHAR(15) NOT NULL DEFAULT 'pendiente',
    observaciones         TEXT,
    CONSTRAINT chk_toma_estado
        CHECK (estado_toma IN ('pendiente', 'tomada', 'omitida', 'cancelada')),
    CONSTRAINT chk_toma_confirmacion
        CHECK (
            (estado_toma = 'tomada' AND fecha_hora_efectiva IS NOT NULL)
            OR (estado_toma <> 'tomada' AND fecha_hora_efectiva IS NULL)
        ),
    CONSTRAINT uq_toma_programada UNIQUE (id_med_horario, fecha_hora_programada),
    CONSTRAINT fk_toma_horario_usuario
        FOREIGN KEY (id_med_horario, id_user)
        REFERENCES medicamento_horario(id_med_horario, id_user)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    INDEX idx_toma_usuario_programada (id_user, fecha_hora_programada),
    INDEX idx_toma_usuario_estado (id_user, estado_toma, fecha_hora_programada)
) ENGINE=InnoDB;

CREATE TABLE doctor_especialidad (
    id_doctor       INT UNSIGNED NOT NULL,
    id_especialidad INT UNSIGNED NOT NULL,
    es_principal    BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id_doctor, id_especialidad),
    CONSTRAINT fk_doc_esp_doctor
        FOREIGN KEY (id_doctor) REFERENCES doctors(id_doctor)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_doc_esp_especialidad
        FOREIGN KEY (id_especialidad) REFERENCES especialidad(id_especialidad)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    INDEX idx_doc_esp_especialidad (id_especialidad, id_doctor)
) ENGINE=InnoDB;

INSERT INTO doctor_especialidad (id_doctor, id_especialidad, es_principal)
SELECT id_doctor, id_especialidad, TRUE
FROM doctors;

ALTER TABLE recordatorios
    ADD COLUMN id_med_horario INT UNSIGNED NULL AFTER id_cita,
    ADD COLUMN tipo VARCHAR(20) NOT NULL DEFAULT 'general' AFTER id_med_horario,
    ADD CONSTRAINT chk_recordatorio_tipo
        CHECK (tipo IN ('general', 'medicamento', 'cita')),
    ADD CONSTRAINT fk_rec_med_horario
        FOREIGN KEY (id_med_horario) REFERENCES medicamento_horario(id_med_horario)
        ON UPDATE RESTRICT ON DELETE SET NULL,
    ADD INDEX idx_recordatorio_med_horario (id_med_horario, fecha);

ALTER TABLE emocion_media
    ADD CONSTRAINT uq_emocion_media_central UNIQUE (id_emo_media, id_emo_cen);

ALTER TABLE emocion_especifica
    ADD CONSTRAINT uq_emocion_especifica_media UNIQUE (id_emo_espe, id_emo_media);

ALTER TABLE emocion_conjunto
    ADD CONSTRAINT fk_conj_especifica_media
        FOREIGN KEY (id_emo_espe, id_emo_media)
        REFERENCES emocion_especifica(id_emo_espe, id_emo_media)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD CONSTRAINT fk_conj_media_central
        FOREIGN KEY (id_emo_media, id_emo_cen)
        REFERENCES emocion_media(id_emo_media, id_emo_cen)
        ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE trackeo_emo
    ADD COLUMN id_intensidad INT UNSIGNED NULL AFTER id_emo_conjunto;

UPDATE trackeo_emo te
JOIN emocion_conjunto eco ON eco.id_emocion_conjun = te.id_emo_conjunto
JOIN emocion_especifica ee ON ee.id_emo_espe = eco.id_emo_espe
SET te.id_intensidad = ee.id_intensidad;

ALTER TABLE trackeo_emo
    MODIFY COLUMN id_intensidad INT UNSIGNED NOT NULL,
    ADD CONSTRAINT fk_track_intensidad
        FOREIGN KEY (id_intensidad) REFERENCES intensidad(id_intensidad)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    ADD INDEX idx_track_user_intensidad_fecha (id_user, id_intensidad, fecha);

INSERT INTO schema_migrations (version, description)
VALUES ('V003', 'complete medication schedules, intake tracking and hierarchy integrity');
