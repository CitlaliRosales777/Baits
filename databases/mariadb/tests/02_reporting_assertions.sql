USE moodsitto;

DELIMITER //
CREATE PROCEDURE assert_report(IN condition_value BOOLEAN, IN failure_message VARCHAR(255))
BEGIN
    IF condition_value IS NULL OR condition_value = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = failure_message;
    END IF;
END//
DELIMITER ;

SET @report_user = (
    SELECT id_user FROM users WHERE mail = 'usuario-db@moodsitto.invalid'
);

SET @report_total = (
    SELECT COUNT(*) FROM trackeo_emo
    WHERE id_user = @report_user AND fecha BETWEEN '2026-01-01' AND '2026-01-31'
);
CALL assert_report(@report_total = 2, 'FAIL: emotional report total');

SET @report_average = (
    SELECT ROUND(AVG(i.valor), 2)
    FROM trackeo_emo te JOIN intensidad i ON i.id_intensidad = te.id_intensidad
    WHERE te.id_user = @report_user
      AND te.fecha BETWEEN '2026-01-01' AND '2026-01-31'
);
CALL assert_report(@report_average = 6.00, 'FAIL: emotional intensity average');

SET @report_frequency = (
    SELECT MAX(frequency_count)
    FROM (
        SELECT COUNT(*) AS frequency_count
        FROM trackeo_emo te
        JOIN emocion_conjunto eco ON eco.id_emocion_conjun = te.id_emo_conjunto
        WHERE te.id_user = @report_user
          AND te.fecha BETWEEN '2026-01-01' AND '2026-01-31'
        GROUP BY eco.id_emo_espe
    ) frequencies
);
CALL assert_report(@report_frequency = 2, 'FAIL: emotional absolute frequency');

SET @report_percentage = ROUND(100 * @report_frequency / NULLIF(@report_total, 0), 2);
CALL assert_report(@report_percentage = 100.00, 'FAIL: emotional percentage');

SET @empty_percentage = ROUND(100 * 0 / NULLIF(0, 0), 2);
CALL assert_report(@empty_percentage IS NULL, 'FAIL: zero division guard');

SET @intake_percentage = (
    SELECT ROUND(100 * SUM(estado_toma = 'tomada') /
        NULLIF(SUM(estado_toma IN ('tomada', 'omitida')), 0), 2)
    FROM toma_medicamento
    WHERE id_user = @report_user
      AND DATE(fecha_hora_programada) BETWEEN '2026-01-01' AND '2026-01-31'
);
CALL assert_report(@intake_percentage = 50.00, 'FAIL: intake compliance report');

DROP PROCEDURE assert_report;
SELECT 'PASS reports: totals, frequency, percentage, averages, empty periods and compliance' AS result;
