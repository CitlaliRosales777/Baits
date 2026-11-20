# Checklist backend

- [ ] Ejecuté `probar-api-publica.ps1` y recibí los tres resultados `[OK]`.
- [ ] Mi código usa `https://api.lvltechmx.com` o rutas `/api` del mismo dominio.
- [ ] No guardé contraseñas de MariaDB o MongoDB en el backend ni en el frontend.

- [ ] Tailscale conectado y autorizado.
- [ ] `.env` creado localmente y excluido de Git.
- [ ] `probar-conexiones` termina con integración preparada.
- [ ] PHP tiene `pdo_mysql`.
- [ ] El componente documental elegido tiene un driver MongoDB compatible.
- [ ] Registro, login, perfil y recordatorios siguen usando MariaDB.
- [ ] Rueda, registros y resúmenes emocionales usan MongoDB.
- [ ] Cada consulta toma `id_user` de la sesión, nunca del cliente sin validar.
- [ ] Contraseñas de usuarios finales usan `password_hash`/`password_verify`.
- [ ] Reintentos entre motores usan una clave de idempotencia.
- [ ] No se usan cuentas administrativas desde la aplicación.

