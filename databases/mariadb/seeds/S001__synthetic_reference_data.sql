-- Datos completamente ficticios para desarrollo y demostración.
USE moodsitto;

INSERT INTO area (nombre_area, descripcion) VALUES
('Psicología', 'Atención psicológica de demostración'),
('Psiquiatría', 'Atención psiquiátrica de demostración');

INSERT INTO especialidad (especialidad, descripcion) VALUES
('Psicología clínica', 'Especialidad ficticia para pruebas'),
('Psiquiatría general', 'Especialidad ficticia para pruebas');

INSERT INTO estados_clinicos (estado_c, descripcion) VALUES
('En evaluación', 'Diagnóstico todavía en evaluación'),
('Confirmado', 'Diagnóstico confirmado por un profesional');

INSERT INTO estado (estado, descripcion) VALUES
('Activo', 'Registro vigente'),
('Completado', 'Actividad terminada'),
('Cancelado', 'Registro cancelado');

INSERT INTO compuesto (compuesto, descripcion, via_admin) VALUES
('Compuesto sintético A', 'No corresponde a un medicamento real', 'Oral');

INSERT INTO dosis (dosis, descripcion) VALUES
('Dosis de prueba', 'Valor no clínico; solo demostración');

INSERT INTO horarios (horario, descripcion) VALUES
('08:00:00', 'Horario matutino de prueba'),
('20:00:00', 'Horario nocturno de prueba');

INSERT INTO intensidad (valor, descripcion, color) VALUES
(3, 'Intensidad baja de demostración', '#8BC34A'),
(6, 'Intensidad media de demostración', '#FFC107'),
(9, 'Intensidad alta de demostración', '#F44336');

INSERT INTO emocion_central (nombre, descripcion, id_intensidad)
SELECT 'Alegría', 'Emoción central de demostración', id_intensidad
FROM intensidad WHERE valor = 6;

INSERT INTO emocion_media (nombre, descripcion, id_intensidad, id_emo_cen)
SELECT 'Entusiasmo', 'Emoción media de demostración', i.id_intensidad, ec.id_emo_cen
FROM intensidad i CROSS JOIN emocion_central ec
WHERE i.valor = 6 AND ec.nombre = 'Alegría';

INSERT INTO emocion_especifica (nombre, descripcion, id_intensidad, id_emo_media)
SELECT 'Motivación', 'Emoción específica de demostración', i.id_intensidad, em.id_emo_media
FROM intensidad i CROSS JOIN emocion_media em
WHERE i.valor = 6 AND em.nombre = 'Entusiasmo';

INSERT INTO emocion_conjunto (id_emo_espe, id_emo_media, id_emo_cen)
SELECT ee.id_emo_espe, em.id_emo_media, ec.id_emo_cen
FROM emocion_especifica ee
JOIN emocion_media em ON em.id_emo_media = ee.id_emo_media
JOIN emocion_central ec ON ec.id_emo_cen = em.id_emo_cen
WHERE ee.nombre = 'Motivación';

