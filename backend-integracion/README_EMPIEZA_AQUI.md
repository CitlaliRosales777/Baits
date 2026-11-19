# Empieza aquí

No instales servidores de bases de datos. DB Manager los administra.

## Windows

1. Conecta Tailscale con la cuenta autorizada.
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

El backend PHP observado usa `DB_HOST`, `DB_NAME`, `DB_USER` y `DB_PASS`. MongoDB todavía requiere que el equipo backend agregue el controlador y las rutas emocionales; consulta la guía técnica.

