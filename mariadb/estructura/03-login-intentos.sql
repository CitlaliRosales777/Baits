-- Compatible con backend/sql/extras.sql de backend-moodsitto y api-citas.
-- Ejecutar en el principal con la cuenta de migraciones.
USE moodsitto;

CREATE TABLE IF NOT EXISTS login_intentos (
    id_intento BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    clave CHAR(64) NOT NULL,
    creado_at DATETIME NOT NULL,
    PRIMARY KEY (id_intento),
    KEY idx_login_intentos_clave (clave, creado_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
