-- Recordatorios del tablero bajo la identidad de APIcore. Sus claves no se cruzan con moodsitto.users.
USE apicore;
CREATE TABLE IF NOT EXISTS tablero_recordatorios (
    user_id INT UNSIGNED NOT NULL,
    recordatorio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    detalle JSON NOT NULL,
    creado_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (user_id, recordatorio_id),
    KEY idx_tablero_recordatorios_fecha (user_id, creado_at),
    CONSTRAINT fk_tablero_recordatorios_usuario FOREIGN KEY (user_id)
        REFERENCES users (UserId) ON DELETE CASCADE
) ENGINE=InnoDB;
