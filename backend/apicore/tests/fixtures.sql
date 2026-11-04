USE moodsitto;

INSERT INTO location (calle, colonia, num_ext, cp, descripcion)
VALUES ('Calle API ficticia', 'Colonia API prueba', '200', '22000', 'Consultorio sintético');

INSERT INTO doctors
    (id_area, cedula, nombre, apellido_p, num_tel, id_location, id_especialidad)
SELECT
    a.id_area, 'CEDULA-API-FICTICIA-001', 'Profesional', 'API', '0000000010',
    l.id_location, e.id_especialidad
FROM area a
JOIN especialidad e ON e.especialidad = 'Psicología clínica'
JOIN location l ON l.calle = 'Calle API ficticia'
WHERE a.nombre_area = 'Psicología';

