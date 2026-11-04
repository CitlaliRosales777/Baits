-- Seguimiento emocional. Sustituir cada ? mediante parámetros enlazados.
USE moodsitto;

-- Registrar una emoción: id_user, id_emocion_conjunto, id_intensidad y contexto.
INSERT INTO trackeo_emo
    (fecha, hora, contexto, id_user, id_emo_conjunto, id_intensidad)
VALUES (CURRENT_DATE, CURRENT_TIME, ?, ?, ?, ?);

-- Historial cronológico por usuario y periodo.
SELECT
    te.id_trackeo, te.fecha, te.hora, te.contexto,
    ec.nombre AS emocion_central,
    em.nombre AS emocion_media,
    ee.nombre AS emocion_especifica,
    i.valor AS intensidad,
    i.color
FROM trackeo_emo te
JOIN emocion_conjunto eco ON eco.id_emocion_conjun = te.id_emo_conjunto
JOIN emocion_central ec ON ec.id_emo_cen = eco.id_emo_cen
JOIN emocion_media em ON em.id_emo_media = eco.id_emo_media
JOIN emocion_especifica ee ON ee.id_emo_espe = eco.id_emo_espe
JOIN intensidad i ON i.id_intensidad = te.id_intensidad
WHERE te.id_user = ?
  AND te.fecha BETWEEN ? AND ?
ORDER BY te.fecha DESC, te.hora DESC;

-- Filtro por emoción específica.
SELECT te.id_trackeo, te.fecha, te.hora, te.contexto, i.valor AS intensidad
FROM trackeo_emo te
JOIN emocion_conjunto eco ON eco.id_emocion_conjun = te.id_emo_conjunto
JOIN intensidad i ON i.id_intensidad = te.id_intensidad
WHERE te.id_user = ? AND eco.id_emo_espe = ?
ORDER BY te.fecha DESC, te.hora DESC;

-- Filtro por rango de intensidad.
SELECT te.id_trackeo, te.fecha, te.hora, te.contexto, i.valor AS intensidad
FROM trackeo_emo te
JOIN intensidad i ON i.id_intensidad = te.id_intensidad
WHERE te.id_user = ? AND i.valor BETWEEN ? AND ?
ORDER BY te.fecha DESC, te.hora DESC;

-- Últimos registros; el límite debe validarse como entero positivo antes de enlazarlo.
SELECT te.id_trackeo, te.fecha, te.hora, te.contexto, ee.nombre, i.valor AS intensidad
FROM trackeo_emo te
JOIN emocion_conjunto eco ON eco.id_emocion_conjun = te.id_emo_conjunto
JOIN emocion_especifica ee ON ee.id_emo_espe = eco.id_emo_espe
JOIN intensidad i ON i.id_intensidad = te.id_intensidad
WHERE te.id_user = ?
ORDER BY te.fecha DESC, te.hora DESC
LIMIT ?;
