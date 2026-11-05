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
CALL assert_equals(@table_count, 23, 'FAIL: expected 23 domain tables');

SET @fk_count = (
    SELECT COUNT(*)
    FROM information_schema.referential_constraints
    WHERE constraint_schema = 'moodsitto'
);
CALL assert_equals(@fk_count, 42, 'FAIL: expected 42 foreign keys');

SET @migration_count = (SELECT COUNT(*) FROM schema_migrations);
CALL assert_equals(@migration_count, 3, 'FAIL: expected three migrations');

SET @engine_count = (
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'moodsitto'
      AND table_type = 'BASE TABLE'
      AND engine = 'InnoDB'
);
CALL assert_equals(@engine_count, 24, 'FAIL: all tables must use InnoDB');

DROP PROCEDURE assert_equals;
SELECT 'PASS schema: 23 tables, 42 FKs, 3 migrations, all InnoDB' AS result;
