CREATE DATABASE IF NOT EXISTS moodsitto
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE moodsitto;

-- ========================================
-- TABLAS PADRE (sin dependencias)
-- ========================================

CREATE TABLE location (
    id_location     INT AUTO_INCREMENT PRIMARY KEY,
    calle           VARCHAR(100) NOT NULL,
    colonia         VARCHAR(50)  NOT NULL,
    num_ext         VARCHAR(10),
    cp              VARCHAR(10),
    num_int         VARCHAR(10),
    descripcion     TEXT
);

CREATE TABLE area (
    id_area         INT AUTO_INCREMENT PRIMARY KEY,
    nombre_area     VARCHAR(100) NOT NULL,
    descripcion     TEXT
);

CREATE TABLE especialidad (
    id_especialidad INT AUTO_INCREMENT PRIMARY KEY,
    especialidad    VARCHAR(50) NOT NULL,
    descripcion     TEXT
);

CREATE TABLE estados_clinicos (
    id_estadoclini  INT AUTO_INCREMENT PRIMARY KEY,
    estado_c        VARCHAR(50) NOT NULL,
    descripcion     TEXT
);

CREATE TABLE estado (
    id_estado       INT AUTO_INCREMENT PRIMARY KEY,
    estado          VARCHAR(50) NOT NULL,
    descripcion     TEXT
);

CREATE TABLE compuesto (
    id_compuesto    INT AUTO_INCREMENT PRIMARY KEY,
    compuesto       VARCHAR(100) NOT NULL,          -- Nombre real del medicamento
    descripcion     TEXT,
    via_admin       VARCHAR(100)
);

CREATE TABLE dosis (
    id_dosis        INT AUTO_INCREMENT PRIMARY KEY,
    dosis           VARCHAR(50) NOT NULL,
    descripcion     TEXT
);

CREATE TABLE horarios (
    id_horario      INT AUTO_INCREMENT PRIMARY KEY,
    horario         TIME NOT NULL,                  -- Mejor TIME que DATE
    descripcion     TEXT
);

CREATE TABLE intensidad (
    id_intensidad   INT AUTO_INCREMENT PRIMARY KEY,
    valor           TINYINT NOT NULL CHECK (valor BETWEEN 1 AND 10),  -- Escala 1-10
    descripcion     TEXT,
    color           VARCHAR(7)                      -- Código HEX (#FFFFFF)
);

-- ========================================
-- TABLAS CON DEPENDENCIAS
-- ========================================

CREATE TABLE users (                                
    id_user         INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    lastname1       VARCHAR(100) NOT NULL,
    lastname2       VARCHAR(100),
    date_b          DATE NOT NULL,
    phone           VARCHAR(15) NOT NULL,           
    emer_phone      VARCHAR(15),
    mail            VARCHAR(100) UNIQUE NOT NULL,
    passw           VARCHAR(255) NOT NULL,           -- Para guardar hash de contraseña
    id_location     INT,
    
    CONSTRAINT fk_user_location
        FOREIGN KEY (id_location) REFERENCES location(id_location)
);

CREATE TABLE doctors (
    id_doctor       INT AUTO_INCREMENT PRIMARY KEY,
    id_area         INT,
    cedula          VARCHAR(100),
    nombre          VARCHAR(100) NOT NULL,
    apellido_p      VARCHAR(100) NOT NULL,
    apellido_m      VARCHAR(100),
    num_tel         VARCHAR(15),
    id_location     INT,
    id_especialidad INT,
    
    CONSTRAINT fk_doctor_area 
        FOREIGN KEY (id_area) REFERENCES area(id_area),
    CONSTRAINT fk_doctor_location 
        FOREIGN KEY (id_location) REFERENCES location(id_location),
    CONSTRAINT fk_doctor_especialidad 
        FOREIGN KEY (id_especialidad) REFERENCES especialidad(id_especialidad)
);

CREATE TABLE diagnosticos (
    id_diagnostico  INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    descripcion     TEXT,
    fecha           DATE,
    documento       VARCHAR(255),                   -- Ruta o nombre del archivo PDF
    id_area         INT,
    id_estadoclini  INT,
    id_user         INT,
    id_doctor       INT,
    id_estado       INT,
    
    CONSTRAINT fk_diag_area 
        FOREIGN KEY (id_area) REFERENCES area(id_area),
    CONSTRAINT fk_diag_estadoclini 
        FOREIGN KEY (id_estadoclini) REFERENCES estados_clinicos(id_estadoclini),
    CONSTRAINT fk_diag_user 
        FOREIGN KEY (id_user) REFERENCES users(id_user),
    CONSTRAINT fk_diag_doctor 
        FOREIGN KEY (id_doctor) REFERENCES doctors(id_doctor),
    CONSTRAINT fk_diag_estado 
        FOREIGN KEY (id_estado) REFERENCES estado(id_estado)
);

CREATE TABLE citas_medicas (
    id_cita         INT AUTO_INCREMENT PRIMARY KEY,
    id_doctor       INT,
    id_location     INT,
    id_area         INT,
    id_estado       INT,
    fecha           DATETIME,
    descripcion     TEXT,
    id_user         INT,                           
    
    CONSTRAINT fk_cita_doctor 
        FOREIGN KEY (id_doctor) REFERENCES doctors(id_doctor),
    CONSTRAINT fk_cita_location 
        FOREIGN KEY (id_location) REFERENCES location(id_location),
    CONSTRAINT fk_cita_area 
        FOREIGN KEY (id_area) REFERENCES area(id_area),
    CONSTRAINT fk_cita_estado 
        FOREIGN KEY (id_estado) REFERENCES estado(id_estado),
    CONSTRAINT fk_cita_user 
        FOREIGN KEY (id_user) REFERENCES users(id_user)
);

CREATE TABLE medicamento (
    id_medicamento  INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    id_compuesto    INT,
    cantidad        INT NOT NULL,
    id_dosis        INT,
    id_estado       INT,
    recomendaciones TEXT,
    advertencias    TEXT,
    tratamiento     VARCHAR(100),
    id_horario      INT,
    id_user         INT,
    
    CONSTRAINT fk_med_compuesto 
        FOREIGN KEY (id_compuesto) REFERENCES compuesto(id_compuesto),
    CONSTRAINT fk_med_dosis 
        FOREIGN KEY (id_dosis) REFERENCES dosis(id_dosis),
    CONSTRAINT fk_med_estado 
        FOREIGN KEY (id_estado) REFERENCES estado(id_estado),
    CONSTRAINT fk_med_horario 
        FOREIGN KEY (id_horario) REFERENCES horarios(id_horario),
    CONSTRAINT fk_med_user 
        FOREIGN KEY (id_user) REFERENCES users(id_user)
);

CREATE TABLE recordatorios (
    id_recordatorio INT AUTO_INCREMENT PRIMARY KEY,
    id_user         INT,
    id_cita         INT,
    id_horario      INT,
    contenido       TEXT,
    id_estado       INT,
    fecha           DATETIME,
    
    CONSTRAINT fk_rec_user 
        FOREIGN KEY (id_user) REFERENCES users(id_user),
    CONSTRAINT fk_rec_cita 
        FOREIGN KEY (id_cita) REFERENCES citas_medicas(id_cita),
    CONSTRAINT fk_rec_horario 
        FOREIGN KEY (id_horario) REFERENCES horarios(id_horario),
    CONSTRAINT fk_rec_estado 
        FOREIGN KEY (id_estado) REFERENCES estado(id_estado)
);

-- ========================================
-- SISTEMA DE EMOCIONES
-- ========================================

CREATE TABLE emocion_central (
    id_emo_cen      INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL,
    descripcion     TEXT,
    id_intensidad   INT,
    
    CONSTRAINT fk_emocen_intensidad 
        FOREIGN KEY (id_intensidad) REFERENCES intensidad(id_intensidad)
);

CREATE TABLE emocion_media (
    id_emo_media    INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL,
    descripcion     TEXT,
    id_intensidad   INT,
    id_emo_cen      INT,
    
    CONSTRAINT fk_emomed_intensidad 
        FOREIGN KEY (id_intensidad) REFERENCES intensidad(id_intensidad),
    CONSTRAINT fk_emomed_central 
        FOREIGN KEY (id_emo_cen) REFERENCES emocion_central(id_emo_cen)
);

CREATE TABLE emocion_especifica (
    id_emo_espe     INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL,
    descripcion     TEXT,
    id_intensidad   INT,
    id_emo_media    INT,
    
    CONSTRAINT fk_emoespe_intensidad 
        FOREIGN KEY (id_intensidad) REFERENCES intensidad(id_intensidad),
    CONSTRAINT fk_emoespe_media 
        FOREIGN KEY (id_emo_media) REFERENCES emocion_media(id_emo_media)
);

CREATE TABLE emocion_conjunto (
    id_emocion_conjun INT AUTO_INCREMENT PRIMARY KEY,
    id_emo_espe     INT,
    id_emo_media    INT,
    id_emo_cen      INT,
    
    CONSTRAINT fk_conj_espe 
        FOREIGN KEY (id_emo_espe) REFERENCES emocion_especifica(id_emo_espe),
    CONSTRAINT fk_conj_media 
        FOREIGN KEY (id_emo_media) REFERENCES emocion_media(id_emo_media),
    CONSTRAINT fk_conj_cen 
        FOREIGN KEY (id_emo_cen) REFERENCES emocion_central(id_emo_cen)
);

CREATE TABLE trackeo_emo (
    id_trackeo      INT AUTO_INCREMENT PRIMARY KEY,
    fecha           DATE NOT NULL,
    hora            TIME NOT NULL,
    contexto        TEXT,
    id_user         INT,
    id_emo_conjunto INT,
    
    CONSTRAINT fk_track_user 
        FOREIGN KEY (id_user) REFERENCES users(id_user),
    CONSTRAINT fk_track_conjunto 
        FOREIGN KEY (id_emo_conjunto) REFERENCES emocion_conjunto(id_emocion_conjun)
);
