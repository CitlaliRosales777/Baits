-- Estadísticas descriptivas para un único usuario autorizado.
-- Parámetros repetidos: id_user, fecha_inicio y fecha_fin.
USE moodsitto;

-- 1. Total de registros.
SELECT COUNT(*) AS total_registros
FROM trackeo_emo
WHERE id_user = ? AND fecha BETWEEN ? AND ?;

-- 2 y 3. Frecuencia absoluta, relativa y porcentaje por emoción específica.
SELECT
    ee.id_emo_espe,
    ee.nombre AS emocion,
    COUNT(*) AS frecuencia_absoluta,
    COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0) AS frecuencia_relativa,
    ROUND(100 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS porcentaje
FROM trackeo_emo te
JOIN emocion_conjunto eco ON eco.id_emocion_conjun = te.id_emo_conjunto
JOIN emocion_especifica ee ON ee.id_emo_espe = eco.id_emo_espe
WHERE te.id_user = ? AND te.fecha BETWEEN ? AND ?
GROUP BY ee.id_emo_espe, ee.nombre
ORDER BY frecuencia_absoluta DESC, ee.nombre;

-- 4. Promedio de la intensidad numérica registrada, no de identificadores.
SELECT ROUND(AVG(i.valor), 2) AS intensidad_promedio
FROM trackeo_emo te
JOIN intensidad i ON i.id_intensidad = te.id_intensidad
WHERE te.id_user = ? AND te.fecha BETWEEN ? AND ?;

-- 5. Emoción más frecuente; los empates se resuelven alfabéticamente.
SELECT ee.id_emo_espe, ee.nombre AS emocion, COUNT(*) AS frecuencia
FROM trackeo_emo te
JOIN emocion_conjunto eco ON eco.id_emocion_conjun = te.id_emo_conjunto
JOIN emocion_especifica ee ON ee.id_emo_espe = eco.id_emo_espe
WHERE te.id_user = ? AND te.fecha BETWEEN ? AND ?
GROUP BY ee.id_emo_espe, ee.nombre
ORDER BY frecuencia DESC, ee.nombre
LIMIT 1;

-- 6. Distribución por categoría central.
SELECT ec.id_emo_cen, ec.nombre AS categoria, COUNT(*) AS total,
       ROUND(100 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS porcentaje
FROM trackeo_emo te
JOIN emocion_conjunto eco ON eco.id_emocion_conjun = te.id_emo_conjunto
JOIN emocion_central ec ON ec.id_emo_cen = eco.id_emo_cen
WHERE te.id_user = ? AND te.fecha BETWEEN ? AND ?
GROUP BY ec.id_emo_cen, ec.nombre
ORDER BY total DESC, ec.nombre;

-- 7. Evolución diaria. Un calendario externo debe completar días sin registros con cero.
SELECT te.fecha AS periodo, COUNT(*) AS total, ROUND(AVG(i.valor), 2) AS intensidad_promedio
FROM trackeo_emo te
JOIN intensidad i ON i.id_intensidad = te.id_intensidad
WHERE te.id_user = ? AND te.fecha BETWEEN ? AND ?
GROUP BY te.fecha
ORDER BY te.fecha;

-- 8. Evolución semanal ISO.
SELECT YEARWEEK(te.fecha, 3) AS periodo_iso, MIN(te.fecha) AS primera_fecha,
       MAX(te.fecha) AS ultima_fecha, COUNT(*) AS total,
       ROUND(AVG(i.valor), 2) AS intensidad_promedio
FROM trackeo_emo te
JOIN intensidad i ON i.id_intensidad = te.id_intensidad
WHERE te.id_user = ? AND te.fecha BETWEEN ? AND ?
GROUP BY YEARWEEK(te.fecha, 3)
ORDER BY periodo_iso;

-- 9. Evolución mensual.
SELECT DATE_FORMAT(te.fecha, '%Y-%m') AS periodo, COUNT(*) AS total,
       ROUND(AVG(i.valor), 2) AS intensidad_promedio
FROM trackeo_emo te
JOIN intensidad i ON i.id_intensidad = te.id_intensidad
WHERE te.id_user = ? AND te.fecha BETWEEN ? AND ?
GROUP BY DATE_FORMAT(te.fecha, '%Y-%m')
ORDER BY periodo;

-- 10 y 12. Historial y serie de tendencia para gráficas.
SELECT te.fecha, te.hora, ee.nombre AS emocion, ec.nombre AS categoria,
       i.valor AS intensidad, te.contexto
FROM trackeo_emo te
JOIN emocion_conjunto eco ON eco.id_emocion_conjun = te.id_emo_conjunto
JOIN emocion_especifica ee ON ee.id_emo_espe = eco.id_emo_espe
JOIN emocion_central ec ON ec.id_emo_cen = eco.id_emo_cen
JOIN intensidad i ON i.id_intensidad = te.id_intensidad
WHERE te.id_user = ? AND te.fecha BETWEEN ? AND ?
ORDER BY te.fecha, te.hora;

-- 11. Comparación descriptiva de dos periodos del mismo usuario.
SELECT periodo, COUNT(*) AS total, ROUND(AVG(intensidad), 2) AS intensidad_promedio
FROM (
    SELECT 'A' AS periodo, i.valor AS intensidad
    FROM trackeo_emo te JOIN intensidad i ON i.id_intensidad = te.id_intensidad
    WHERE te.id_user = ? AND te.fecha BETWEEN ? AND ?
    UNION ALL
    SELECT 'B' AS periodo, i.valor AS intensidad
    FROM trackeo_emo te JOIN intensidad i ON i.id_intensidad = te.id_intensidad
    WHERE te.id_user = ? AND te.fecha BETWEEN ? AND ?
) comparacion
GROUP BY periodo
ORDER BY periodo;
