-- Datos de EJEMPLO para probar las citas en la laptop (médicos, áreas y lugares ficticios).
-- No es para producción: ahí los catálogos los carga el equipo de base de datos.
-- Se puede correr varias veces sin duplicar nada. Se corre con la misma cuenta que extras.sql.

INSERT IGNORE INTO area (nombre_area, descripcion) VALUES
  ('Psicología',        'Atención psicológica'),
  ('Psiquiatría',       'Atención psiquiátrica'),
  ('Medicina general',  'Consulta general');

INSERT IGNORE INTO especialidad (especialidad, descripcion) VALUES
  ('Psicología clínica', NULL),
  ('Psiquiatría adultos', NULL),
  ('Medicina familiar',  NULL);

INSERT INTO location (calle, colonia, num_ext, cp, descripcion)
SELECT 'Av. Ejemplo', 'Centro', '100', '22000', 'Consultorio de prueba'
 WHERE NOT EXISTS (SELECT 1 FROM location WHERE calle = 'Av. Ejemplo' AND colonia = 'Centro');

INSERT INTO location (calle, colonia, num_ext, cp, descripcion)
SELECT 'Calle Prueba', 'Zona Río', '25', '22010', 'Clínica de prueba'
 WHERE NOT EXISTS (SELECT 1 FROM location WHERE calle = 'Calle Prueba' AND colonia = 'Zona Río');

INSERT IGNORE INTO doctors (id_area, cedula, nombre, apellido_p, apellido_m, num_tel, id_location, id_especialidad)
SELECT a.id_area, 'PRUEBA-0001', 'Laura', 'Méndez', 'Ruiz', '6640000001', l.id_location, e.id_especialidad
  FROM area a, location l, especialidad e
 WHERE a.nombre_area = 'Psicología' AND l.calle = 'Av. Ejemplo' AND e.especialidad = 'Psicología clínica'
 LIMIT 1;

INSERT IGNORE INTO doctors (id_area, cedula, nombre, apellido_p, apellido_m, num_tel, id_location, id_especialidad)
SELECT a.id_area, 'PRUEBA-0002', 'Jorge', 'Salas', NULL, '6640000002', l.id_location, e.id_especialidad
  FROM area a, location l, especialidad e
 WHERE a.nombre_area = 'Psiquiatría' AND l.calle = 'Calle Prueba' AND e.especialidad = 'Psiquiatría adultos'
 LIMIT 1;
