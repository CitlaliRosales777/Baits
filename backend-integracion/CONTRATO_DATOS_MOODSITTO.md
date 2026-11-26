# Contrato de datos Moodsitto

## MariaDB

La versión híbrida tiene 23 tablas. El backend existente usa:

- `users`: registro, login y perfil. `passw` contiene hash, nunca texto plano.
- `estado` y `recordatorios`: recordatorios generales, citas y medicamentos.
- `citas_medicas`, `doctors`, `area`, `location`, `especialidad` y `estado` respaldan citas y catálogos en `api-citas`.
- `api_tokens` guarda hashes de tokens del backend. `login_intentos` se agrega con [la migración complementaria](../mariadb/estructura/03-login-intentos.sql).
- `medicamento`, `medicamento_horario` y `toma_medicamento` quedan pendientes de endpoints.
- `auditoria_eventos`: acciones relacionales sin secretos ni contenido clínico.

El contrato PHP observado espera `users(name, lastname1, lastname2, date_b, phone, emer_phone, mail, passw)` y usa PDO MySQL con consultas preparadas.

## MongoDB `moodsitto`

- `catalogo_emociones`: catálogo jerárquico por `codigo`, `nivel` y `parent_codigo`.
- `registros_emocionales`: `id_user`, `emocion_codigo`, intensidad 1–10, fecha, contexto e idempotencia.
- `resumenes_emocionales`: agregados por usuario y periodo, versionados.
- `auditoria_documental`: acción, recurso, resultado, correlación y metadatos no sensibles.

`id_user` es una referencia lógica a `MariaDB.users.id_user`; no hay FK entre motores. Toda operación debe filtrar por el usuario autenticado. Para una escritura entre motores: validar usuario en MariaDB, generar `idempotency_key`, escribir el documento con `writeConcern: majority`, registrar resultado y reintentar de forma idempotente. No existe transacción automática entre ambos motores.

