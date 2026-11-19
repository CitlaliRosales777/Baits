# Errores frecuentes

- **Tailscale no disponible:** abre Tailscale y confirma que ves `desktop-smecf2n`, `lvltechmx` y la laptop. Solicita acceso a DB Manager.
- **Puerto 3306 no responde:** tu IP Tailscale no está autorizada o MariaDB no está disponible. Reporta tu IP a DB Manager; no desactives el firewall.
- **Access denied en MariaDB:** usuario, contraseña u origen no autorizado. No uses `root`.
- **Puerto 27017 no responde:** el nodo está apagado o tu origen no está autorizado. La URI debe incluir los tres miembros y `replicaSet=rsMoodsitto`.
- **Authentication failed en MongoDB:** verifica `MONGODB_AUTH_SOURCE=moodsitto` y solicita credenciales de aplicación.
- **Falta `mariadb`, `mongosh` o un controlador:** instala solo el cliente/controlador indicado por el responsable backend; no instales servidores.
- **Replica set sin mayoría:** deben estar disponibles al menos dos de los tres miembros. En clase, enciende la laptop.
- **El `.env` ya existe:** el asistente no lo sobrescribe sin confirmación y crea una copia con fecha.

No envíes capturas que muestren `.env`, URI con contraseña, tokens o datos personales.

