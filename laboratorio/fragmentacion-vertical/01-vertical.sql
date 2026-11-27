-- Divide las columnas de los registros ficticios en dos fragmentos.
USE moodsitto_lab;
CREATE TABLE IF NOT EXISTS persona_fuente (
  id INT PRIMARY KEY,
  alias VARCHAR(40) NOT NULL,
  correo_sintetico VARCHAR(100) NOT NULL,
  telefono_sintetico VARCHAR(20) NOT NULL
) ENGINE=InnoDB;
TRUNCATE TABLE persona_fuente;
INSERT INTO persona_fuente VALUES
  (1,'persona_sintetica_01','p01@example.invalid','0000000001'),
  (2,'persona_sintetica_02','p02@example.invalid','0000000002');

CREATE TABLE IF NOT EXISTS persona_identidad (id INT PRIMARY KEY, alias VARCHAR(40) NOT NULL) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS persona_contacto (id INT PRIMARY KEY, correo_sintetico VARCHAR(100) NOT NULL, telefono_sintetico VARCHAR(20) NOT NULL) ENGINE=InnoDB;
TRUNCATE TABLE persona_identidad;
TRUNCATE TABLE persona_contacto;
INSERT INTO persona_identidad SELECT id,alias FROM persona_fuente;
INSERT INTO persona_contacto SELECT id,correo_sintetico,telefono_sintetico FROM persona_fuente;

CREATE OR REPLACE VIEW personas_reconstruidas AS
SELECT i.id,i.alias,c.correo_sintetico,c.telefono_sintetico
FROM persona_identidad i JOIN persona_contacto c ON c.id=i.id;

