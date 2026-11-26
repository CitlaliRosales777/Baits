# Checklist backend

- [ ] El equipo confirmó el enlace APIcore → backend y la correspondencia entre identidades.
- [ ] Cada servicio con acceso SQL usa su esquema y su propia cuenta autorizada.
- [ ] Tailscale conectado y autorizado.
- [ ] `.env` creado localmente y excluido de Git.
- [ ] `probar-conexiones` termina con integración preparada.
- [ ] PHP tiene `pdo_mysql`.
- [ ] DB Manager verificó `login_intentos`, `api_tokens` y los permisos de la cuenta de aplicación.
- [ ] El componente documental elegido tiene un driver MongoDB compatible.
- [ ] Registro, login, perfil y recordatorios siguen usando MariaDB.
- [ ] Rueda, registros y resúmenes emocionales usan MongoDB.
- [ ] Cada consulta usa el `id_user` de la identidad autenticada.
- [ ] Contraseñas de usuarios finales usan `password_hash`/`password_verify`.
- [ ] Reintentos entre motores usan una clave de idempotencia.
- [ ] No se usan cuentas administrativas desde la aplicación.
- [ ] El equipo responsable confirmó el contrato de tokens, cabeceras y rutas de APIcore.

