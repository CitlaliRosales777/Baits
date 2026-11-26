# Empieza aquí

No instales servidores de bases de datos. DB Manager los administra.

El flujo acordado es `cliente → APIcore → backend → bases de datos`. Esta guía configura el acceso del backend a Moodsitto. APIcore tiene un esquema y una configuración propios en `api-citas`. Lee [APIcore y Moodsitto](ARQUITECTURA_APICORE.md) antes de integrar los servicios.

## Qué contraseñas solicita el asistente

El asistente pide dos credenciales que debe entregar DB Manager por un canal privado:

1. La contraseña del usuario de aplicación `moodsitto_app` de MariaDB.
2. La contraseña del usuario de aplicación `moodsitto_app` de MongoDB.

No son contraseñas personales, de APIcore, del frontend ni de los usuarios finales. Tampoco se deben inventar. Los valores reales no aparecen en este README porque el archivo se publica en GitHub.

Después de recibirlas, el asistente las guarda en `backend-integracion\.env` únicamente en el equipo donde se ejecutará el backend. Ese archivo está excluido de Git y no debe enviarse por chat, correo ni capturas de pantalla.

## Windows

1. En el entorno que ejecutará el backend, conecta Tailscale con la cuenta autorizada.
2. Abre PowerShell en esta carpeta.
3. Ejecuta `Set-ExecutionPolicy -Scope Process Bypass`.
4. Ejecuta `.\configurar.ps1` e introduce las dos contraseñas cuando las solicite. No aparecerán en pantalla.
5. Ejecuta `.\probar-conexiones.ps1`.
6. Solo cuando termine con `[OK] Integración preparada`, inicia el backend PHP según su README.

## Linux

1. Conecta Tailscale.
2. Abre una terminal en esta carpeta.
3. Ejecuta `chmod +x configurar.sh probar-conexiones.sh`.
4. Ejecuta `./configurar.sh` y después `./probar-conexiones.sh`.

El asistente crea `.env` únicamente en tu computadora. Nunca lo envíes por chat ni lo subas a Git. Si falla algo, abre `ERRORES_FRECUENTES.md` y reporta a DB Manager el mensaje sin contraseñas.

Configura el proceso PHP con `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` y `DB_PASS` del archivo generado. El código PHP lee `backend/.env` o las variables del proceso. El verificador lee el archivo de esta carpeta. MongoDB queda disponible para cuando el equipo backend integre el controlador y las rutas emocionales.

