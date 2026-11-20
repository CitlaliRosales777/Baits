# Seguridad operativa

- Crear cuentas distintas: administrador personal, `moodsitto_app`, `moodsitto_repl` y operador de respaldo.
- Limitar host/origen a Tailscale y aplicar firewall por IP confirmada. Nunca usar `0.0.0.0/0`.
- Guardar secretos en `.env` local con ACL del usuario, no en argumentos, logs o Git.
- MongoDB usa `authorization: enabled` y keyfile generado en cada servidor fuera del repositorio. Distribuirlo por canal seguro con permisos 600.
- El backend jamás usa `root` ni un usuario MongoDB con `root`/`userAdminAnyDatabase`.
- Mantener `password_hash`/`password_verify` del backend PHP y consultas preparadas.
- Revisar `git grep` y `git diff` antes de cada push. Los respaldos y evidencias privadas están ignorados.

MongoDB Community no incluye todas las capacidades empresariales de auditoría. `auditoria_documental` registra eventos de aplicación con mínimo privilegio; los logs del servidor complementan, pero no sustituyen, una solución empresarial. MariaDB Community puede usar registros generales/lentos y auditoría según el plugin realmente disponible; el script no supone que el plugin esté instalado.

