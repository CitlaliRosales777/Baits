-- Ejecutar como administrador después de crear la base.
-- La creación de usuarios y sus contraseñas se realiza fuera de Git mediante el
-- gestor de secretos del entorno. Estos roles no contienen credenciales.
CREATE ROLE IF NOT EXISTS moodsitto_app_role;
CREATE ROLE IF NOT EXISTS moodsitto_readonly_role;
CREATE ROLE IF NOT EXISTS moodsitto_migration_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON moodsitto.* TO moodsitto_app_role;
GRANT SELECT ON moodsitto.* TO moodsitto_readonly_role;
GRANT ALL PRIVILEGES ON moodsitto.* TO moodsitto_migration_role;

-- Ejemplo de asignación posterior (reemplace el usuario ya creado de forma segura):
-- GRANT moodsitto_app_role TO 'moodsitto_api'@'%';
-- SET DEFAULT ROLE moodsitto_app_role FOR 'moodsitto_api'@'%';

