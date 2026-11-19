CREATE DATABASE IF NOT EXISTS moodsitto_lab CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE moodsitto_lab;

CREATE TABLE IF NOT EXISTS usuarios_fuente (
  id INT PRIMARY KEY,
  alias VARCHAR(40) NOT NULL,
  region ENUM('norte','sur') NOT NULL
) ENGINE=InnoDB;
TRUNCATE TABLE usuarios_fuente;
INSERT INTO usuarios_fuente VALUES
  (1,'persona_sintetica_01','norte'),(2,'persona_sintetica_02','sur'),
  (3,'persona_sintetica_03','norte'),(4,'persona_sintetica_04','sur');

CREATE TABLE IF NOT EXISTS usuarios_norte LIKE usuarios_fuente;
CREATE TABLE IF NOT EXISTS usuarios_sur LIKE usuarios_fuente;
TRUNCATE TABLE usuarios_norte;
TRUNCATE TABLE usuarios_sur;
INSERT INTO usuarios_norte SELECT * FROM usuarios_fuente WHERE region='norte';
INSERT INTO usuarios_sur SELECT * FROM usuarios_fuente WHERE region='sur';

CREATE OR REPLACE VIEW usuarios_reconstruidos AS
SELECT * FROM usuarios_norte
UNION ALL
SELECT * FROM usuarios_sur;

