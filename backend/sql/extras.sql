-- Tabla extra para el bloqueo por intentos fallidos de login.
-- Se corre una sola vez, con una cuenta que pueda crear tablas (no con la de la API).
-- Si el equipo de base de datos la prefiere en otro lugar, solo hay que mover este archivo.

CREATE TABLE IF NOT EXISTS login_intentos (
    id_intento BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    clave      CHAR(64)        NOT NULL,
    creado_at  DATETIME        NOT NULL,
    PRIMARY KEY (id_intento),
    KEY idx_login_intentos_clave (clave, creado_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
