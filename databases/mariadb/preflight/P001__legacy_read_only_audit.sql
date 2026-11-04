-- Diagnóstico de solo lectura antes de migrar una instalación creada con bd-moodsitto.sql.
-- No modifica datos ni estructura.
USE moodsitto;

SELECT 'domain_table_count' AS check_name, COUNT(*) AS finding_count
FROM information_schema.tables
WHERE table_schema = 'moodsitto'
  AND table_type = 'BASE TABLE'
  AND table_name <> 'schema_migrations';

SELECT 'duplicate_user_mail' AS check_name, COUNT(*) AS finding_count
FROM (SELECT mail FROM users GROUP BY mail HAVING COUNT(*) > 1) AS duplicates;

SELECT 'invalid_intensity' AS check_name, COUNT(*) AS finding_count
FROM intensidad WHERE valor NOT BETWEEN 1 AND 10;

SELECT 'orphan_or_incomplete_appointments' AS check_name, COUNT(*) AS finding_count
FROM citas_medicas
WHERE id_doctor IS NULL OR id_location IS NULL OR id_area IS NULL
   OR id_estado IS NULL OR fecha IS NULL OR id_user IS NULL;

SELECT 'orphan_or_incomplete_medications' AS check_name, COUNT(*) AS finding_count
FROM medicamento
WHERE id_compuesto IS NULL OR cantidad IS NULL OR cantidad <= 0 OR id_dosis IS NULL
   OR id_estado IS NULL OR id_horario IS NULL OR id_user IS NULL;

SELECT 'orphan_or_incomplete_diagnoses' AS check_name, COUNT(*) AS finding_count
FROM diagnosticos
WHERE fecha IS NULL OR id_area IS NULL OR id_estadoclini IS NULL OR id_user IS NULL
   OR id_doctor IS NULL OR id_estado IS NULL;

SELECT 'incomplete_emotion_hierarchy' AS check_name, COUNT(*) AS finding_count
FROM emocion_conjunto
WHERE id_emo_espe IS NULL OR id_emo_media IS NULL OR id_emo_cen IS NULL;

SELECT 'inconsistent_emotion_hierarchy' AS check_name, COUNT(*) AS finding_count
FROM emocion_conjunto eco
JOIN emocion_especifica ee ON ee.id_emo_espe = eco.id_emo_espe
JOIN emocion_media em ON em.id_emo_media = eco.id_emo_media
WHERE ee.id_emo_media <> eco.id_emo_media OR em.id_emo_cen <> eco.id_emo_cen;

