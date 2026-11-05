-- Demostración local de fragmentación lógica; no crea nodos distribuidos.
USE moodsitto;

CREATE OR REPLACE VIEW vw_users_identity_fragment AS
SELECT id_user, name, lastname1, lastname2, date_b
FROM users;

CREATE OR REPLACE VIEW vw_users_contact_fragment AS
SELECT id_user, phone, emer_phone, mail, id_location
FROM users;

CREATE OR REPLACE VIEW vw_users_reconstructed AS
SELECT
    i.id_user, i.name, i.lastname1, i.lastname2, i.date_b,
    c.phone, c.emer_phone, c.mail, c.id_location
FROM vw_users_identity_fragment i
JOIN vw_users_contact_fragment c USING (id_user);

CREATE OR REPLACE VIEW vw_trackeo_recent_fragment AS
SELECT id_trackeo, fecha, hora, contexto, id_user, id_emo_conjunto
FROM trackeo_emo
WHERE fecha >= CURRENT_DATE - INTERVAL 90 DAY;

CREATE OR REPLACE VIEW vw_trackeo_archive_fragment AS
SELECT id_trackeo, fecha, hora, contexto, id_user, id_emo_conjunto
FROM trackeo_emo
WHERE fecha < CURRENT_DATE - INTERVAL 90 DAY;

-- Reconstrucción horizontal de ejemplo:
-- SELECT * FROM vw_trackeo_recent_fragment
-- UNION ALL
-- SELECT * FROM vw_trackeo_archive_fragment;
