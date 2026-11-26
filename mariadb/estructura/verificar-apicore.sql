-- Ejecutar conectado a apicore como la cuenta del servicio.
-- LIMIT 0 valida el contrato de lectura sin devolver datos.
SELECT MoodId, MoodName, MoodStatus FROM moods LIMIT 0;
SELECT ExampleId, ExampleName, ExampleCode, ExampleDescription, ExamplePrice,
       ExampleQuantity, ExampleBigNumber, ExampleRatio, ExampleActive, ExampleStatus,
       ExampleBirthDate, ExampleCreatedAt, ExampleStartTime, ExampleYear,
       ExampleMetadata, ExamplePicture
FROM `example` LIMIT 0;
SELECT UserId, Username, Password, Name, PaternalSurname, MaternalSurname,
       Email, BirthDate, Phone, EmergencyPhone, UserStatus, UserRole
FROM users LIMIT 0;
SELECT TokenId, UserId, TokenHash, TokenExpiration, TokenCreatedAt
FROM users_tokens LIMIT 0;
SELECT 'OK: contrato SQL de APIcore accesible' AS resultado;
