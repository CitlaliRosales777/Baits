-- Moodsitto: creación no destructiva del esquema y control de migraciones.
CREATE DATABASE IF NOT EXISTS moodsitto
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE moodsitto;

CREATE TABLE IF NOT EXISTS schema_migrations (
    version         VARCHAR(20)  NOT NULL,
    description     VARCHAR(255) NOT NULL,
    applied_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (version)
) ENGINE=InnoDB;

INSERT INTO schema_migrations (version, description)
VALUES ('V001', 'create database and migration ledger');

