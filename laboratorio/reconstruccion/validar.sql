-- Compara la reconstrucción horizontal y vertical con el total de origen.
USE moodsitto_lab;
SELECT 'horizontal' prueba,
       (SELECT COUNT(*) FROM usuarios_fuente) fuente,
       (SELECT COUNT(*) FROM usuarios_reconstruidos) reconstruida,
       (SELECT COUNT(*) FROM usuarios_fuente)=(SELECT COUNT(*) FROM usuarios_reconstruidos) aprobado;
SELECT 'vertical' prueba,
       (SELECT COUNT(*) FROM persona_fuente) fuente,
       (SELECT COUNT(*) FROM personas_reconstruidas) reconstruida,
       (SELECT COUNT(*) FROM persona_fuente)=(SELECT COUNT(*) FROM personas_reconstruidas) aprobado;
SELECT * FROM usuarios_reconstruidos ORDER BY id;
SELECT * FROM personas_reconstruidas ORDER BY id;
