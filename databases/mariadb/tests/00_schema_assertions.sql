USE moodsitto;

DELIMITER //
CREATE PROCEDURE assert_equals(
    IN actual_value BIGINT,
    IN expected_value BIGINT,
    IN assertion_name VARCHAR(255)
)
BEGIN
    IF actual_value <> expected_value THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = assertion_name;
    END IF;
END//
DELIMITER ;

SET @table_count = (
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'moodsitto'
      AND table_type = 'BASE TABLE'
      AND table_name <> 'schema_migrations'
);
CALL assert_equals(@table_count, 20, 'FAIL: expected 20 domain tables');

SET @fk_count = (
    SELECT COUNT(*)
    FROM information_schema.referential_constraints
    WHERE constraint_schema = 'moodsitto'
);
CALL assert_equals(@fk_count, 33, 'FAIL: expected 33 foreign keys');

SET @migration_count = (SELECT COUNT(*) FROM schema_migrations);
CALL assert_equals(@migration_count, 2, 'FAIL: expected two migrations');

SET @engine_count = (
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'moodsitto'
      AND table_type = 'BASE TABLE'
      AND engine = 'InnoDB'
);
CALL assert_equals(@engine_count, 21, 'FAIL: all tables must use InnoDB');

DROP PROCEDURE assert_equals;
SELECT 'PASS schema: 20 tables, 33 FKs, 2 migrations, all InnoDB' AS result;

