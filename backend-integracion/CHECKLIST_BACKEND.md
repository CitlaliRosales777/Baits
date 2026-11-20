# Checklist backend

- [ ] APIcore llama al backend; APIcore y frontend no se conectan directamente a las bases.
- [ ] Las credenciales DB existen únicamente en el entorno donde corre el backend.
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
- [ ] El equipo responsable confirmó el contrato de tokens, cabeceras y rutas de APIcore.

