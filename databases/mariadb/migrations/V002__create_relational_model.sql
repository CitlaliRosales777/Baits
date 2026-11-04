-- Modelo relacional definitivo compatible con los nombres de bd-moodsitto.sql.
-- Esta migración se aplica después de V001 sobre una base limpia.
USE moodsitto;

CREATE TABLE location (
    id_location     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    calle           VARCHAR(100) NOT NULL,
    colonia         VARCHAR(50)  NOT NULL,
    num_ext         VARCHAR(10),
    cp              VARCHAR(10),
    num_int         VARCHAR(10),
    descripcion     TEXT
) ENGINE=InnoDB;

CREATE TABLE area (
    id_area         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre_area     VARCHAR(100) NOT NULL,
    descripcion     TEXT,
    CONSTRAINT uq_area_nombre UNIQUE (nombre_area)
) ENGINE=InnoDB;

CREATE TABLE especialidad (
    id_especialidad INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    especialidad    VARCHAR(50) NOT NULL,
    descripcion     TEXT,
    CONSTRAINT uq_especialidad_nombre UNIQUE (especialidad)
) ENGINE=InnoDB;

CREATE TABLE estados_clinicos (
    id_estadoclini  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    estado_c        VARCHAR(50) NOT NULL,
    descripcion     TEXT,
    CONSTRAINT uq_estado_clinico_nombre UNIQUE (estado_c)
) ENGINE=InnoDB;

CREATE TABLE estado (
    id_estado       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    estado          VARCHAR(50) NOT NULL,
    descripcion     TEXT,
    CONSTRAINT uq_estado_nombre UNIQUE (estado)
) ENGINE=InnoDB;

CREATE TABLE compuesto (
    id_compuesto    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    compuesto       VARCHAR(100) NOT NULL,
    descripcion     TEXT,
    via_admin       VARCHAR(100),
    CONSTRAINT uq_compuesto_nombre_via UNIQUE (compuesto, via_admin)
) ENGINE=InnoDB;

CREATE TABLE dosis (
    id_dosis        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    dosis           VARCHAR(50) NOT NULL,
    descripcion     TEXT,
    CONSTRAINT uq_dosis_nombre UNIQUE (dosis)
) ENGINE=InnoDB;

CREATE TABLE horarios (
    id_horario      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    horario         TIME NOT NULL,
    descripcion     TEXT,
    CONSTRAINT uq_horario_hora UNIQUE (horario)
) ENGINE=InnoDB;

CREATE TABLE intensidad (
    id_intensidad   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    valor           TINYINT UNSIGNED NOT NULL,
    descripcion     TEXT,
    color           CHAR(7),
    CONSTRAINT uq_intensidad_valor UNIQUE (valor),
    CONSTRAINT chk_intensidad_rango CHECK (valor BETWEEN 1 AND 10),
    CONSTRAINT chk_intensidad_color CHECK (color IS NULL OR color REGEXP '^#[0-9A-Fa-f]{6}$')
) ENGINE=InnoDB;

CREATE TABLE users (
    id_user         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    lastname1       VARCHAR(100) NOT NULL,
    lastname2       VARCHAR(100),
    date_b          DATE NOT NULL,
    phone           VARCHAR(15) NOT NULL,
    emer_phone      VARCHAR(15),
    mail            VARCHAR(254) NOT NULL,
    passw           VARCHAR(255) NOT NULL COMMENT 'Hash producido por APIcore; nunca texto plano',
    id_location     INT UNSIGNED,
    CONSTRAINT uq_users_mail UNIQUE (mail),
    CONSTRAINT fk_user_location FOREIGN KEY (id_location)
        REFERENCES location(id_location) ON UPDATE RESTRICT ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE doctors (
    id_doctor       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_area         INT UNSIGNED NOT NULL,
    cedula          VARCHAR(100) NOT NULL,
    nombre          VARCHAR(100) NOT NULL,
    apellido_p      VARCHAR(100) NOT NULL,
    apellido_m      VARCHAR(100),
    num_tel         VARCHAR(15),
    id_location     INT UNSIGNED,
    id_especialidad INT UNSIGNED NOT NULL,
    CONSTRAINT uq_doctors_cedula UNIQUE (cedula),
    CONSTRAINT fk_doctor_area FOREIGN KEY (id_area)
        REFERENCES area(id_area) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_doctor_location FOREIGN KEY (id_location)
        REFERENCES location(id_location) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_doctor_especialidad FOREIGN KEY (id_especialidad)
        REFERENCES especialidad(id_especialidad) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE diagnosticos (
    id_diagnostico  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    descripcion     TEXT,
    fecha           DATE NOT NULL,
    documento       VARCHAR(255),
    id_area         INT UNSIGNED NOT NULL,
    id_estadoclini  INT UNSIGNED NOT NULL,
    id_user         INT UNSIGNED NOT NULL,
    id_doctor       INT UNSIGNED NOT NULL,
    id_estado       INT UNSIGNED NOT NULL,
    CONSTRAINT fk_diag_area FOREIGN KEY (id_area)
        REFERENCES area(id_area) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_diag_estadoclini FOREIGN KEY (id_estadoclini)
        REFERENCES estados_clinicos(id_estadoclini) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_diag_user FOREIGN KEY (id_user)
        REFERENCES users(id_user) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_diag_doctor FOREIGN KEY (id_doctor)
        REFERENCES doctors(id_doctor) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_diag_estado FOREIGN KEY (id_estado)
        REFERENCES estado(id_estado) ON UPDATE RESTRICT ON DELETE RESTRICT,
    INDEX idx_diag_user_fecha (id_user, fecha),
    INDEX idx_diag_doctor_fecha (id_doctor, fecha)
) ENGINE=InnoDB;

CREATE TABLE citas_medicas (
    id_cita         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_doctor       INT UNSIGNED NOT NULL,
    id_location     INT UNSIGNED NOT NULL,
    id_area         INT UNSIGNED NOT NULL,
    id_estado       INT UNSIGNED NOT NULL,
    fecha           DATETIME NOT NULL,
    descripcion     TEXT,
    id_user         INT UNSIGNED NOT NULL,
    CONSTRAINT fk_cita_doctor FOREIGN KEY (id_doctor)
        REFERENCES doctors(id_doctor) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_cita_location FOREIGN KEY (id_location)
        REFERENCES location(id_location) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_cita_area FOREIGN KEY (id_area)
        REFERENCES area(id_area) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_cita_estado FOREIGN KEY (id_estado)
        REFERENCES estado(id_estado) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_cita_user FOREIGN KEY (id_user)
        REFERENCES users(id_user) ON UPDATE RESTRICT ON DELETE RESTRICT,
    INDEX idx_citas_user_fecha (id_user, fecha),
    INDEX idx_citas_doctor_fecha (id_doctor, fecha),
    INDEX idx_citas_estado_fecha (id_estado, fecha)
) ENGINE=InnoDB;

CREATE TABLE medicamento (
    id_medicamento  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    id_compuesto    INT UNSIGNED NOT NULL,
    cantidad        INT UNSIGNED NOT NULL,
    id_dosis        INT UNSIGNED NOT NULL,
    id_estado       INT UNSIGNED NOT NULL,
    recomendaciones TEXT,
    advertencias    TEXT,
    tratamiento     VARCHAR(100),
    id_horario      INT UNSIGNED NOT NULL,
    id_user         INT UNSIGNED NOT NULL,
    CONSTRAINT chk_medicamento_cantidad CHECK (cantidad > 0),
    CONSTRAINT fk_med_compuesto FOREIGN KEY (id_compuesto)
        REFERENCES compuesto(id_compuesto) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_med_dosis FOREIGN KEY (id_dosis)
        REFERENCES dosis(id_dosis) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_med_estado FOREIGN KEY (id_estado)
        REFERENCES estado(id_estado) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_med_horario FOREIGN KEY (id_horario)
        REFERENCES horarios(id_horario) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_med_user FOREIGN KEY (id_user)
        REFERENCES users(id_user) ON UPDATE RESTRICT ON DELETE RESTRICT,
    INDEX idx_medicamento_user_estado (id_user, id_estado),
    INDEX idx_medicamento_horario (id_horario)
) ENGINE=InnoDB;

CREATE TABLE recordatorios (
    id_recordatorio INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_user         INT UNSIGNED NOT NULL,
    id_cita         INT UNSIGNED,
    id_horario      INT UNSIGNED NOT NULL,
    contenido       TEXT NOT NULL,
    id_estado       INT UNSIGNED NOT NULL,
    fecha           DATETIME NOT NULL,
    CONSTRAINT fk_rec_user FOREIGN KEY (id_user)
        REFERENCES users(id_user) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_rec_cita FOREIGN KEY (id_cita)
        REFERENCES citas_medicas(id_cita) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_rec_horario FOREIGN KEY (id_horario)
        REFERENCES horarios(id_horario) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_rec_estado FOREIGN KEY (id_estado)
        REFERENCES estado(id_estado) ON UPDATE RESTRICT ON DELETE RESTRICT,
    INDEX idx_recordatorio_user_fecha (id_user, fecha),
    INDEX idx_recordatorio_estado_fecha (id_estado, fecha)
) ENGINE=InnoDB;

CREATE TABLE emocion_central (
    id_emo_cen      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL,
    descripcion     TEXT,
    id_intensidad   INT UNSIGNED NOT NULL,
    CONSTRAINT uq_emocion_central_nombre UNIQUE (nombre),
    CONSTRAINT fk_emocen_intensidad FOREIGN KEY (id_intensidad)
        REFERENCES intensidad(id_intensidad) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE emocion_media (
    id_emo_media    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL,
    descripcion     TEXT,
    id_intensidad   INT UNSIGNED NOT NULL,
    id_emo_cen      INT UNSIGNED NOT NULL,
    CONSTRAINT uq_emocion_media_padre_nombre UNIQUE (id_emo_cen, nombre),
    CONSTRAINT fk_emomed_intensidad FOREIGN KEY (id_intensidad)
        REFERENCES intensidad(id_intensidad) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_emomed_central FOREIGN KEY (id_emo_cen)
        REFERENCES emocion_central(id_emo_cen) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE emocion_especifica (
    id_emo_espe     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL,
    descripcion     TEXT,
    id_intensidad   INT UNSIGNED NOT NULL,
    id_emo_media    INT UNSIGNED NOT NULL,
    CONSTRAINT uq_emocion_especifica_padre_nombre UNIQUE (id_emo_media, nombre),
    CONSTRAINT fk_emoespe_intensidad FOREIGN KEY (id_intensidad)
        REFERENCES intensidad(id_intensidad) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_emoespe_media FOREIGN KEY (id_emo_media)
        REFERENCES emocion_media(id_emo_media) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE emocion_conjunto (
    id_emocion_conjun INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_emo_espe       INT UNSIGNED NOT NULL,
    id_emo_media      INT UNSIGNED NOT NULL,
    id_emo_cen        INT UNSIGNED NOT NULL,
    CONSTRAINT uq_emocion_conjunto UNIQUE (id_emo_espe, id_emo_media, id_emo_cen),
    CONSTRAINT fk_conj_espe FOREIGN KEY (id_emo_espe)
        REFERENCES emocion_especifica(id_emo_espe) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_conj_media FOREIGN KEY (id_emo_media)
        REFERENCES emocion_media(id_emo_media) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_conj_cen FOREIGN KEY (id_emo_cen)
        REFERENCES emocion_central(id_emo_cen) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE trackeo_emo (
    id_trackeo      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    fecha           DATE NOT NULL,
    hora            TIME NOT NULL,
    contexto        TEXT,
    id_user         INT UNSIGNED NOT NULL,
    id_emo_conjunto INT UNSIGNED NOT NULL,
    CONSTRAINT fk_track_user FOREIGN KEY (id_user)
        REFERENCES users(id_user) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_track_conjunto FOREIGN KEY (id_emo_conjunto)
        REFERENCES emocion_conjunto(id_emocion_conjun) ON UPDATE RESTRICT ON DELETE RESTRICT,
    INDEX idx_track_user_fecha_hora (id_user, fecha, hora),
    INDEX idx_track_emocion_fecha (id_emo_conjunto, fecha)
) ENGINE=InnoDB;

INSERT INTO schema_migrations (version, description)
VALUES ('V002', 'create compatible relational model with integrity rules');

