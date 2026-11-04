-- Diagnóstico de solo lectura antes de migrar una instalación creada con bd-moodsitto.sql.
-- No modifica datos ni estructura.
USE moodsitto;

-- El primer resultado es informativo. En todos los resultados siguientes,
-- finding_count debe ser cero antes de aplicar las restricciones de V002.
SELECT 'observed_domain_table_count' AS check_name, COUNT(*) AS finding_count
FROM information_schema.tables
WHERE table_schema = 'moodsitto'
  AND table_type = 'BASE TABLE'
  AND table_name <> 'schema_migrations';

-- Violaciones de NOT NULL incorporadas en V002.
SELECT 'null_required_location' AS check_name, COUNT(*) AS finding_count
FROM location WHERE calle IS NULL OR colonia IS NULL
UNION ALL
SELECT 'null_required_area', COUNT(*) FROM area WHERE nombre_area IS NULL
UNION ALL
SELECT 'null_required_especialidad', COUNT(*) FROM especialidad WHERE especialidad IS NULL
UNION ALL
SELECT 'null_required_estados_clinicos', COUNT(*) FROM estados_clinicos WHERE estado_c IS NULL
UNION ALL
SELECT 'null_required_estado', COUNT(*) FROM estado WHERE estado IS NULL
UNION ALL
SELECT 'null_required_compuesto', COUNT(*) FROM compuesto
WHERE compuesto IS NULL OR via_admin IS NULL
UNION ALL
SELECT 'null_required_dosis', COUNT(*) FROM dosis WHERE dosis IS NULL
UNION ALL
SELECT 'null_required_horarios', COUNT(*) FROM horarios WHERE horario IS NULL
UNION ALL
SELECT 'null_required_intensidad', COUNT(*) FROM intensidad WHERE valor IS NULL
UNION ALL
SELECT 'null_required_users', COUNT(*) FROM users
WHERE name IS NULL OR lastname1 IS NULL OR date_b IS NULL OR phone IS NULL
   OR mail IS NULL OR passw IS NULL
UNION ALL
SELECT 'null_required_doctors', COUNT(*) FROM doctors
WHERE id_area IS NULL OR cedula IS NULL OR nombre IS NULL OR apellido_p IS NULL
   OR id_especialidad IS NULL
UNION ALL
SELECT 'null_required_diagnosticos', COUNT(*) FROM diagnosticos
WHERE nombre IS NULL OR fecha IS NULL OR id_area IS NULL OR id_estadoclini IS NULL
   OR id_user IS NULL OR id_doctor IS NULL OR id_estado IS NULL
UNION ALL
SELECT 'null_required_citas_medicas', COUNT(*) FROM citas_medicas
WHERE id_doctor IS NULL OR id_location IS NULL OR id_area IS NULL
   OR id_estado IS NULL OR fecha IS NULL OR id_user IS NULL
UNION ALL
SELECT 'null_required_medicamento', COUNT(*) FROM medicamento
WHERE nombre IS NULL OR id_compuesto IS NULL OR cantidad IS NULL OR id_dosis IS NULL
   OR id_estado IS NULL OR id_horario IS NULL OR id_user IS NULL
UNION ALL
SELECT 'null_required_recordatorios', COUNT(*) FROM recordatorios
WHERE id_user IS NULL OR id_horario IS NULL OR contenido IS NULL
   OR id_estado IS NULL OR fecha IS NULL
UNION ALL
SELECT 'null_required_emocion_central', COUNT(*) FROM emocion_central
WHERE nombre IS NULL OR id_intensidad IS NULL
UNION ALL
SELECT 'null_required_emocion_media', COUNT(*) FROM emocion_media
WHERE nombre IS NULL OR id_intensidad IS NULL OR id_emo_cen IS NULL
UNION ALL
SELECT 'null_required_emocion_especifica', COUNT(*) FROM emocion_especifica
WHERE nombre IS NULL OR id_intensidad IS NULL OR id_emo_media IS NULL
UNION ALL
SELECT 'null_required_emocion_conjunto', COUNT(*) FROM emocion_conjunto
WHERE id_emo_espe IS NULL OR id_emo_media IS NULL OR id_emo_cen IS NULL
UNION ALL
SELECT 'null_required_trackeo_emo', COUNT(*) FROM trackeo_emo
WHERE fecha IS NULL OR hora IS NULL OR id_user IS NULL OR id_emo_conjunto IS NULL;

-- Duplicados que impedirían crear las restricciones UNIQUE de V002.
SELECT 'duplicate_area_nombre' AS check_name, COUNT(*) AS finding_count
FROM (SELECT nombre_area FROM area GROUP BY nombre_area HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_especialidad_nombre', COUNT(*) FROM
  (SELECT especialidad FROM especialidad GROUP BY especialidad HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_estado_clinico_nombre', COUNT(*) FROM
  (SELECT estado_c FROM estados_clinicos GROUP BY estado_c HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_estado_nombre', COUNT(*) FROM
  (SELECT estado FROM estado GROUP BY estado HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_compuesto_nombre_via', COUNT(*) FROM
  (SELECT compuesto, via_admin FROM compuesto
   GROUP BY compuesto, via_admin HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_dosis_nombre', COUNT(*) FROM
  (SELECT dosis FROM dosis GROUP BY dosis HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_horario', COUNT(*) FROM
  (SELECT horario FROM horarios GROUP BY horario HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_intensidad_valor', COUNT(*) FROM
  (SELECT valor FROM intensidad GROUP BY valor HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_user_mail', COUNT(*) FROM
  (SELECT mail FROM users GROUP BY mail HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_doctor_cedula', COUNT(*) FROM
  (SELECT cedula FROM doctors GROUP BY cedula HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_emocion_central_nombre', COUNT(*) FROM
  (SELECT nombre FROM emocion_central GROUP BY nombre HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_emocion_media_padre_nombre', COUNT(*) FROM
  (SELECT id_emo_cen, nombre FROM emocion_media
   GROUP BY id_emo_cen, nombre HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_emocion_especifica_padre_nombre', COUNT(*) FROM
  (SELECT id_emo_media, nombre FROM emocion_especifica
   GROUP BY id_emo_media, nombre HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'duplicate_emocion_conjunto', COUNT(*) FROM
  (SELECT id_emo_espe, id_emo_media, id_emo_cen FROM emocion_conjunto
   GROUP BY id_emo_espe, id_emo_media, id_emo_cen HAVING COUNT(*) > 1) AS d;

-- Violaciones de CHECK incorporadas en V002.
SELECT 'invalid_intensity_range' AS check_name, COUNT(*) AS finding_count
FROM intensidad WHERE valor NOT BETWEEN 1 AND 10
UNION ALL
SELECT 'invalid_intensity_color', COUNT(*) FROM intensidad
WHERE color IS NOT NULL AND color NOT REGEXP '^#[0-9A-Fa-f]{6}$'
UNION ALL
SELECT 'invalid_medication_quantity', COUNT(*) FROM medicamento
WHERE cantidad <= 0;

-- Coherencia adicional que las FK simples no pueden expresar.
SELECT 'inconsistent_emotion_hierarchy' AS check_name, COUNT(*) AS finding_count
FROM emocion_conjunto eco
JOIN emocion_especifica ee ON ee.id_emo_espe = eco.id_emo_espe
JOIN emocion_media em ON em.id_emo_media = eco.id_emo_media
WHERE ee.id_emo_media <> eco.id_emo_media OR em.id_emo_cen <> eco.id_emo_cen;

