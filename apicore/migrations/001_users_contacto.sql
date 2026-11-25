-- Agrega a `users` los datos que pide el registro de Moodsitto.
-- Para una base `apicore` que ya existe:
--   mysql -u root -p apicore < migrations/001_users_contacto.sql
-- (apicore.sql ya incluye estas columnas para instalaciones nuevas)
--
-- Son NULL para que las cuentas existentes (godtest, admintest...) sigan siendo validas.

ALTER TABLE `users`
  ADD COLUMN `Email` varchar(100) DEFAULT NULL AFTER `MaternalSurname`,
  ADD COLUMN `BirthDate` date DEFAULT NULL AFTER `Email`,
  ADD COLUMN `Phone` varchar(15) DEFAULT NULL AFTER `BirthDate`,
  ADD COLUMN `EmergencyPhone` varchar(15) DEFAULT NULL AFTER `Phone`,
  ADD UNIQUE KEY `Email` (`Email`);
