-- MOODSITTO v2 | MariaDB 11.4+ | INSTALACION LIMPIA UNICAMENTE
-- Compatible con backend-moodsitto: users(name,lastname1,lastname2,date_b,phone,emer_phone,mail,passw).
-- NO ejecutar en una BD preexistente: este script usa CREATE TABLE sin alterar datos historicos.
-- Seguridad real tambien requiere autorizar cada solicitud en APIcore y hardening del servidor.
-- NO incluye usuarios, contrasenas, datos reales ni secretos.

CREATE DATABASE IF NOT EXISTS moodsitto
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE moodsitto;


-- PARTE 1. INFORMACIÓN SOBRE LA INSTALACIÓN
-- Guarda un registro para saber qué versión de la base de datos se instaló.
--
-- schema_migrations: Versiones de la base de datos
-- Anota qué cambios se han instalado, para que el equipo sepa qué versión está usando.
CREATE TABLE schema_migrations (
  version VARCHAR(64) NOT NULL PRIMARY KEY,
  description VARCHAR(255) NOT NULL,
  applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;


-- PARTE 2. DATOS QUE SE USAN EN VARIAS PANTALLAS
-- Aquí van opciones que pueden repetirse, como direcciones, especialidades y horarios.
--
-- location: Direcciones
-- Guarda direcciones de usuarios, consultorios u otros lugares de atención.
CREATE TABLE location (
  id_location INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  calle VARCHAR(100) NOT NULL,
  colonia VARCHAR(50) NOT NULL,
  num_ext VARCHAR(10), cp VARCHAR(10), num_int VARCHAR(10), descripcion TEXT
) ENGINE=InnoDB;


-- area: Áreas de atención
-- Guarda nombres de áreas, como medicina general o psicología, para elegirlas después.
CREATE TABLE area (
  id_area INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre_area VARCHAR(100) NOT NULL UNIQUE,
  descripcion TEXT
) ENGINE=InnoDB;


-- especialidad: Especialidades médicas
-- Guarda especialidades que pueden tener los médicos, como pediatría o psiquiatría.
CREATE TABLE especialidad (
  id_especialidad INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  especialidad VARCHAR(50) NOT NULL UNIQUE,
  descripcion TEXT
) ENGINE=InnoDB;


-- estados_clinicos: Estado de un diagnóstico
-- Indica en qué situación se encuentra un diagnóstico. Los nombres concretos los define el equipo.
CREATE TABLE estados_clinicos (
  id_estadoclini INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  estado_c VARCHAR(50) NOT NULL UNIQUE,
  descripcion TEXT
) ENGINE=InnoDB;


-- estado: Situación de un registro
-- Permite marcar en qué estado está una cita, un medicamento o un recordatorio.
CREATE TABLE estado (
  id_estado INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  estado VARCHAR(50) NOT NULL UNIQUE,
  descripcion TEXT
) ENGINE=InnoDB;


-- compuesto: Contenido principal del medicamento
-- Guarda el nombre de la sustancia del medicamento y cómo se administra.
CREATE TABLE compuesto (
  id_compuesto INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  compuesto VARCHAR(100) NOT NULL,
  descripcion TEXT,
  via_admin VARCHAR(100) NOT NULL,
  CONSTRAINT uq_compuesto_via UNIQUE (compuesto, via_admin)
) ENGINE=InnoDB;


-- dosis: Dosis
-- Guarda las dosis que se pueden seleccionar al registrar un medicamento.
CREATE TABLE dosis (
  id_dosis INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  dosis VARCHAR(50) NOT NULL UNIQUE,
  descripcion TEXT
) ENGINE=InnoDB;


-- horarios: Horas
-- Guarda horas, como 08:00 o 20:00, para organizar medicamentos y avisos.
CREATE TABLE horarios (
  id_horario INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  horario TIME NOT NULL UNIQUE,
  descripcion TEXT
) ENGINE=InnoDB;


-- intensidad: Qué tan fuerte se siente algo
-- Guarda valores del 1 al 10 para indicar intensidad, con un color opcional.
CREATE TABLE intensidad (
  id_intensidad INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  valor TINYINT UNSIGNED NOT NULL UNIQUE,
  descripcion TEXT,
  color CHAR(7),
  CONSTRAINT chk_intensidad_1_10 CHECK (valor BETWEEN 1 AND 10),
  CONSTRAINT chk_intensidad_hex CHECK (color IS NULL OR color REGEXP '^#[0-9a-fA-F]{6}$')
) ENGINE=InnoDB;


-- PARTE 3. PERSONAS, MÉDICOS Y CITAS
-- Guarda quién usa la aplicación y la información relacionada con su atención médica.
--
-- users: Cuentas de las personas
-- Guarda nombre, correo, teléfonos y datos necesarios para iniciar sesión.
-- La contraseña real NO se guarda aquí; se guarda una versión protegida.
CREATE TABLE users (
  id_user INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  lastname1 VARCHAR(100) NOT NULL,
  lastname2 VARCHAR(100),
  date_b DATE NOT NULL,
  phone VARCHAR(15) NOT NULL,
  emer_phone VARCHAR(15),
  mail VARCHAR(254) NOT NULL,
  passw VARCHAR(255) NOT NULL COMMENT 'La contraseña se guarda protegida; nunca se guarda el texto original.',
  id_location INT UNSIGNED,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  email_verified_at DATETIME NULL,
  password_changed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  CONSTRAINT uq_user_mail UNIQUE (mail),
  CONSTRAINT chk_user_passw_hash CHECK (CHAR_LENGTH(passw) >= 30),
  CONSTRAINT fk_user_location FOREIGN KEY (id_location) REFERENCES location(id_location)
     ON UPDATE RESTRICT ON DELETE SET NULL
) ENGINE=InnoDB;


-- doctors: Médicos y especialistas
-- Guarda nombre, teléfono, especialidad y lugar de atención de cada profesional.
CREATE TABLE doctors (
  id_doctor INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_area INT UNSIGNED NOT NULL,
  cedula VARCHAR(100),
  nombre VARCHAR(100) NOT NULL,
  apellido_p VARCHAR(100) NOT NULL,
  apellido_m VARCHAR(100),
  num_tel VARCHAR(15),
  id_location INT UNSIGNED,
  id_especialidad INT UNSIGNED NOT NULL,
  CONSTRAINT uq_doctor_cedula UNIQUE (cedula),
  CONSTRAINT fk_doctor_area FOREIGN KEY (id_area) REFERENCES area(id_area) ON DELETE RESTRICT,
  CONSTRAINT fk_doctor_location FOREIGN KEY (id_location) REFERENCES location(id_location) ON DELETE SET NULL,
  CONSTRAINT fk_doctor_especialidad FOREIGN KEY (id_especialidad) REFERENCES especialidad(id_especialidad) ON DELETE RESTRICT
) ENGINE=InnoDB;


-- doctor_especialidad: Un médico con varias especialidades
-- Permite que un mismo médico aparezca con más de una especialidad.
CREATE TABLE doctor_especialidad (
  id_doctor INT UNSIGNED NOT NULL,
  id_especialidad INT UNSIGNED NOT NULL,
  es_principal BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY(id_doctor, id_especialidad),
  CONSTRAINT fk_de_doctor FOREIGN KEY (id_doctor) REFERENCES doctors(id_doctor) ON DELETE RESTRICT,
  CONSTRAINT fk_de_especialidad FOREIGN KEY (id_especialidad) REFERENCES especialidad(id_especialidad) ON DELETE RESTRICT,
  INDEX idx_de_especialidad (id_especialidad, id_doctor)
) ENGINE=InnoDB;


-- diagnosticos: Diagnósticos
-- Guarda el diagnóstico de una persona, la fecha, el médico y, si existe, su documento.
-- El documento no debe quedar disponible para cualquier usuario.
CREATE TABLE diagnosticos (
  id_diagnostico INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  descripcion TEXT,
  fecha DATE NOT NULL,
  documento VARCHAR(255) COMMENT 'Dónde está el documento. La aplicación debe comprobar quién puede verlo.',
  id_area INT UNSIGNED NOT NULL,
  id_estadoclini INT UNSIGNED NOT NULL,
  id_user INT UNSIGNED NOT NULL,
  id_doctor INT UNSIGNED NOT NULL,
  id_estado INT UNSIGNED NOT NULL,
  CONSTRAINT fk_diag_area FOREIGN KEY (id_area) REFERENCES area(id_area) ON DELETE RESTRICT,
  CONSTRAINT fk_diag_clinico FOREIGN KEY (id_estadoclini) REFERENCES estados_clinicos(id_estadoclini) ON DELETE RESTRICT,
  CONSTRAINT fk_diag_user FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE RESTRICT,
  CONSTRAINT fk_diag_doctor FOREIGN KEY (id_doctor) REFERENCES doctors(id_doctor) ON DELETE RESTRICT,
  CONSTRAINT fk_diag_estado FOREIGN KEY (id_estado) REFERENCES estado(id_estado) ON DELETE RESTRICT,
  INDEX idx_diag_user_fecha (id_user, fecha)
) ENGINE=InnoDB;


-- citas_medicas: Citas médicas
-- Guarda con qué médico es la cita, el lugar, la fecha, la hora y su situación.
CREATE TABLE citas_medicas (
  id_cita INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_doctor INT UNSIGNED NOT NULL,
  id_location INT UNSIGNED NOT NULL,
  id_area INT UNSIGNED NOT NULL,
  id_estado INT UNSIGNED NOT NULL,
  fecha DATETIME NOT NULL COMMENT 'La aplicación debe manejar bien las horas para que la cita aparezca correctamente.',
  descripcion TEXT,
  id_user INT UNSIGNED NOT NULL,
  CONSTRAINT uq_cita_user UNIQUE (id_cita, id_user),
  CONSTRAINT fk_cita_doctor FOREIGN KEY (id_doctor) REFERENCES doctors(id_doctor) ON DELETE RESTRICT,
  CONSTRAINT fk_cita_location FOREIGN KEY (id_location) REFERENCES location(id_location) ON DELETE RESTRICT,
  CONSTRAINT fk_cita_area FOREIGN KEY (id_area) REFERENCES area(id_area) ON DELETE RESTRICT,
  CONSTRAINT fk_cita_estado FOREIGN KEY (id_estado) REFERENCES estado(id_estado) ON DELETE RESTRICT,
  CONSTRAINT fk_cita_user FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE RESTRICT,
  INDEX idx_cita_user_fecha (id_user, fecha),
  INDEX idx_cita_doctor_fecha (id_doctor, fecha)
) ENGINE=InnoDB;


-- PARTE 4. MEDICAMENTOS Y SUS TOMAS
-- Permite guardar un tratamiento y llevar el control de cuándo se debe tomar.
--
-- medicamento: Medicamentos registrados
-- Guarda qué medicamento usa una persona, la cantidad indicada y las fechas del tratamiento.
CREATE TABLE medicamento (
  id_medicamento INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  id_compuesto INT UNSIGNED NOT NULL,
  cantidad INT UNSIGNED NOT NULL,
  unidad_medida VARCHAR(30),
  id_dosis INT UNSIGNED NOT NULL,
  id_estado INT UNSIGNED NOT NULL,
  recomendaciones TEXT,
  advertencias TEXT,
  tratamiento VARCHAR(100),
  fecha_inicio DATE,
  fecha_fin DATE,
  id_horario INT UNSIGNED NOT NULL COMMENT 'Hora principal. Las otras horas se guardan en medicamento_horario.',
  id_user INT UNSIGNED NOT NULL,
  CONSTRAINT uq_med_usuario UNIQUE (id_medicamento, id_user),
  CONSTRAINT chk_med_cantidad CHECK (cantidad > 0),
  CONSTRAINT chk_med_fechas CHECK (fecha_inicio IS NULL OR fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
  CONSTRAINT fk_med_compuesto FOREIGN KEY (id_compuesto) REFERENCES compuesto(id_compuesto) ON DELETE RESTRICT,
  CONSTRAINT fk_med_dosis FOREIGN KEY (id_dosis) REFERENCES dosis(id_dosis) ON DELETE RESTRICT,
  CONSTRAINT fk_med_estado FOREIGN KEY (id_estado) REFERENCES estado(id_estado) ON DELETE RESTRICT,
  CONSTRAINT fk_med_horario FOREIGN KEY (id_horario) REFERENCES horarios(id_horario) ON DELETE RESTRICT,
  CONSTRAINT fk_med_user FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE RESTRICT,
  INDEX idx_med_user_estado (id_user, id_estado)
) ENGINE=InnoDB;


-- medicamento_horario: Horarios para tomar medicamentos
-- Permite indicar varias horas para un mismo medicamento.
-- Ejemplo: una pastilla a las 08:00 y otra a las 20:00.
CREATE TABLE medicamento_horario (
  id_med_horario INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_medicamento INT UNSIGNED NOT NULL,
  id_user INT UNSIGNED NOT NULL,
  id_horario INT UNSIGNED NOT NULL,
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  indicaciones TEXT,
  CONSTRAINT uq_mh_programacion UNIQUE (id_medicamento, id_horario, fecha_inicio),
  CONSTRAINT uq_mh_user UNIQUE (id_med_horario, id_user),
  CONSTRAINT chk_mh_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
  CONSTRAINT fk_mh_med_user FOREIGN KEY (id_medicamento, id_user) REFERENCES medicamento(id_medicamento, id_user) ON DELETE RESTRICT,
  CONSTRAINT fk_mh_hora FOREIGN KEY (id_horario) REFERENCES horarios(id_horario) ON DELETE RESTRICT,
  INDEX idx_mh_user_activo (id_user, activo, fecha_inicio, fecha_fin)
) ENGINE=InnoDB;


-- toma_medicamento: Registro de cada toma
-- Guarda si una toma estaba pendiente, si se realizó o si se omitió.
-- También puede anotar a qué hora se tomó realmente.
CREATE TABLE toma_medicamento (
  id_toma BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_med_horario INT UNSIGNED NOT NULL,
  id_user INT UNSIGNED NOT NULL,
  fecha_hora_programada DATETIME NOT NULL,
  fecha_hora_efectiva DATETIME,
  estado_toma VARCHAR(15) NOT NULL DEFAULT 'pendiente',
  observaciones TEXT,
  CONSTRAINT uq_toma_hora UNIQUE (id_med_horario, fecha_hora_programada),
  CONSTRAINT chk_toma_estado CHECK (estado_toma IN ('pendiente','tomada','omitida','cancelada')),
  CONSTRAINT chk_toma_efectiva CHECK (
    (estado_toma='tomada' AND fecha_hora_efectiva IS NOT NULL) OR
    (estado_toma<>'tomada' AND fecha_hora_efectiva IS NULL)
  ),
  CONSTRAINT fk_toma_mh_user FOREIGN KEY (id_med_horario, id_user) REFERENCES medicamento_horario(id_med_horario, id_user) ON DELETE RESTRICT,
  INDEX idx_toma_user_programada (id_user, fecha_hora_programada),
  INDEX idx_toma_user_estado (id_user, estado_toma, fecha_hora_programada)
) ENGINE=InnoDB;


-- PARTE 5. RECORDATORIOS
-- Sirve para programar avisos de citas, medicamentos u otras actividades.
--
-- recordatorios: Avisos que quiere recibir el usuario
-- Guarda el mensaje y la fecha del aviso. Puede ser sobre una cita o un medicamento.
CREATE TABLE recordatorios (
  id_recordatorio INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_user INT UNSIGNED NOT NULL,
  id_cita INT UNSIGNED,
  id_med_horario INT UNSIGNED,
  id_horario INT UNSIGNED COMMENT 'Se mantiene para que siga funcionando el código de versiones anteriores.',
  tipo VARCHAR(20) NOT NULL DEFAULT 'general',
  contenido TEXT NOT NULL,
  id_estado INT UNSIGNED NOT NULL,
  fecha DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_recordatorio_user UNIQUE (id_recordatorio, id_user),
  CONSTRAINT chk_rec_tipo CHECK (
    (tipo='general' AND id_cita IS NULL AND id_med_horario IS NULL) OR
    (tipo='cita' AND id_cita IS NOT NULL AND id_med_horario IS NULL) OR
    (tipo='medicamento' AND id_cita IS NULL AND id_med_horario IS NOT NULL)
  ),
  CONSTRAINT fk_rec_user FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE RESTRICT,
  CONSTRAINT fk_rec_cita_user FOREIGN KEY (id_cita, id_user) REFERENCES citas_medicas(id_cita, id_user) ON DELETE RESTRICT,
  CONSTRAINT fk_rec_mh_user FOREIGN KEY (id_med_horario, id_user) REFERENCES medicamento_horario(id_med_horario, id_user) ON DELETE RESTRICT,
  CONSTRAINT fk_rec_hora FOREIGN KEY (id_horario) REFERENCES horarios(id_horario) ON DELETE RESTRICT,
  CONSTRAINT fk_rec_estado FOREIGN KEY (id_estado) REFERENCES estado(id_estado) ON DELETE RESTRICT,
  INDEX idx_rec_user_fecha (id_user, fecha),
  INDEX idx_rec_estado_fecha (id_estado, fecha)
) ENGINE=InnoDB;


-- PARTE 6. EMOCIONES
-- Organiza la rueda de emociones y guarda cómo se ha sentido cada persona.
--
-- emocion_central: Emociones generales
-- Guarda el primer nivel de la rueda, por ejemplo, alegría o tristeza.
CREATE TABLE emocion_central (
  id_emo_cen INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL UNIQUE,
  descripcion TEXT,
  id_intensidad INT UNSIGNED NOT NULL,
  CONSTRAINT fk_ec_int FOREIGN KEY (id_intensidad) REFERENCES intensidad(id_intensidad) ON DELETE RESTRICT
) ENGINE=InnoDB;


-- emocion_media: Emociones más detalladas
-- Guarda el segundo nivel de la rueda, dentro de una emoción general.
CREATE TABLE emocion_media (
  id_emo_media INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL,
  descripcion TEXT,
  id_intensidad INT UNSIGNED NOT NULL,
  id_emo_cen INT UNSIGNED NOT NULL,
  CONSTRAINT uq_em_jerarquia UNIQUE (id_emo_media, id_emo_cen),
  CONSTRAINT uq_em_nombre UNIQUE (id_emo_cen, nombre),
  CONSTRAINT fk_em_int FOREIGN KEY (id_intensidad) REFERENCES intensidad(id_intensidad) ON DELETE RESTRICT,
  CONSTRAINT fk_em_cen FOREIGN KEY (id_emo_cen) REFERENCES emocion_central(id_emo_cen) ON DELETE RESTRICT
) ENGINE=InnoDB;


-- emocion_especifica: Emociones muy concretas
-- Guarda el tercer nivel para elegir con mayor detalle cómo se siente la persona.
CREATE TABLE emocion_especifica (
  id_emo_espe INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL,
  descripcion TEXT,
  id_intensidad INT UNSIGNED NOT NULL,
  id_emo_media INT UNSIGNED NOT NULL,
  CONSTRAINT uq_ee_jerarquia UNIQUE (id_emo_espe, id_emo_media),
  CONSTRAINT uq_ee_nombre UNIQUE (id_emo_media, nombre),
  CONSTRAINT fk_ee_int FOREIGN KEY (id_intensidad) REFERENCES intensidad(id_intensidad) ON DELETE RESTRICT,
  CONSTRAINT fk_ee_media FOREIGN KEY (id_emo_media) REFERENCES emocion_media(id_emo_media) ON DELETE RESTRICT
) ENGINE=InnoDB;


-- emocion_conjunto: Conexión entre los niveles de la rueda
-- Une las emociones generales, detalladas y concretas que pertenecen a la misma opción.
CREATE TABLE emocion_conjunto (
  id_emocion_conjun INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_emo_espe INT UNSIGNED NOT NULL,
  id_emo_media INT UNSIGNED NOT NULL,
  id_emo_cen INT UNSIGNED NOT NULL,
  CONSTRAINT uq_ecj_tripleta UNIQUE (id_emo_espe,id_emo_media,id_emo_cen),
  CONSTRAINT fk_ecj_ee_em FOREIGN KEY (id_emo_espe, id_emo_media)
    REFERENCES emocion_especifica(id_emo_espe, id_emo_media) ON DELETE RESTRICT,
  CONSTRAINT fk_ecj_em_ec FOREIGN KEY (id_emo_media, id_emo_cen)
    REFERENCES emocion_media(id_emo_media, id_emo_cen) ON DELETE RESTRICT
) ENGINE=InnoDB;


-- trackeo_emo: Diario de emociones
-- Guarda qué emoción eligió la persona, cuándo la sintió y lo que quiso escribir.
-- Estos datos son privados y no deben mostrarse a otras personas sin permiso.
CREATE TABLE trackeo_emo (
  id_trackeo INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  fecha DATE NOT NULL,
  hora TIME NOT NULL,
  contexto TEXT,
  id_user INT UNSIGNED NOT NULL,
  id_emo_conjunto INT UNSIGNED NOT NULL,
  id_intensidad INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_track_user FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE RESTRICT,
  CONSTRAINT fk_track_conjunto FOREIGN KEY (id_emo_conjunto) REFERENCES emocion_conjunto(id_emocion_conjun) ON DELETE RESTRICT,
  CONSTRAINT fk_track_int FOREIGN KEY (id_intensidad) REFERENCES intensidad(id_intensidad) ON DELETE RESTRICT,
  INDEX idx_track_user_fecha (id_user, fecha, hora),
  INDEX idx_track_emo_fecha (id_emo_conjunto, fecha)
) ENGINE=InnoDB;


-- PARTE 7. AVISOS Y PROTECCIÓN DE DATOS
-- Organiza los avisos y registra algunos aspectos importantes de la seguridad.
--
-- notificaciones: Envío de notificaciones
-- Guarda qué aviso debe enviarse, por dónde y si ya se envió.
-- También ayuda a evitar que el mismo aviso se mande dos veces.
CREATE TABLE notificaciones (
  id_notificacion BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_user INT UNSIGNED NOT NULL,
  id_recordatorio INT UNSIGNED,
  canal VARCHAR(12) NOT NULL,
  estado_envio VARCHAR(12) NOT NULL DEFAULT 'pendiente',
  idempotency_key CHAR(64) NOT NULL,
  programada_at DATETIME NOT NULL,
  enviada_at DATETIME,
  intentos SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  ultimo_error_codigo VARCHAR(60),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_notif_canal CHECK (canal IN ('email','push','inapp')),
  CONSTRAINT chk_notif_estado CHECK (estado_envio IN ('pendiente','procesando','enviada','fallida','cancelada')),
  CONSTRAINT uq_notif_idempotencia UNIQUE (id_user, idempotency_key),
  CONSTRAINT fk_notif_user FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE RESTRICT,
  CONSTRAINT fk_notif_rec_user FOREIGN KEY (id_recordatorio,id_user)
    REFERENCES recordatorios(id_recordatorio,id_user) ON DELETE RESTRICT,
  INDEX idx_notif_worker (estado_envio,programada_at)
) ENGINE=InnoDB;


-- consentimientos: Permisos que acepta cada usuario
-- Guarda qué autorización aceptó la persona y si después decidió retirarla.
CREATE TABLE consentimientos (
  id_consentimiento BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_user INT UNSIGNED NOT NULL,
  tipo VARCHAR(50) NOT NULL,
  version_texto VARCHAR(32) NOT NULL,
  aceptado_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revocado_at DATETIME,
  CONSTRAINT fk_consent_user FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE RESTRICT,
  CONSTRAINT chk_consent_tiempo CHECK (revocado_at IS NULL OR revocado_at >= aceptado_at),
  INDEX idx_consent_user_tipo (id_user,tipo,aceptado_at)
) ENGINE=InnoDB;


-- api_tokens: Sesiones iniciadas
-- Ayuda a reconocer una sesión sin guardar directamente su clave de acceso.
-- Permite que la aplicación cierre o deje de aceptar una sesión.
CREATE TABLE api_tokens (
  id_token BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_user INT UNSIGNED NOT NULL,
  token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  creado_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expira_at DATETIME NOT NULL,
  revocado_at DATETIME,
  CONSTRAINT uq_token_hash UNIQUE (token_hash),
  CONSTRAINT fk_token_user FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE RESTRICT,
  CONSTRAINT chk_token_fechas CHECK (expira_at > creado_at),
  INDEX idx_token_user_expira (id_user,expira_at)
) ENGINE=InnoDB;


-- auditoria_eventos: Registro de acciones importantes
-- Anota acciones como cambios o accesos rechazados, para revisar problemas.
-- No debe guardar contraseñas ni información médica privada.
CREATE TABLE auditoria_eventos (
  id_evento BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  actor_id_user INT UNSIGNED,
  accion VARCHAR(60) NOT NULL,
  recurso VARCHAR(60) NOT NULL,
  recurso_id VARCHAR(64),
  resultado VARCHAR(12) NOT NULL,
  correlacion_id CHAR(36),
  creado_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_audit_resultado CHECK (resultado IN ('ok','denegado','error')),
  CONSTRAINT fk_audit_actor FOREIGN KEY (actor_id_user) REFERENCES users(id_user) ON DELETE SET NULL,
  INDEX idx_audit_actor (actor_id_user,creado_at),
  INDEX idx_audit_recurso (recurso,creado_at)
) ENGINE=InnoDB;

-- FIN DE LA INSTALACIÓN
-- Guarda la fecha y la versión de esta base de datos.
INSERT INTO schema_migrations (version,description)
VALUES ('2026-11-09-v2-clean','Compatible con frontend, Moodsitto PHP backend, y adaptador de APIcore');
