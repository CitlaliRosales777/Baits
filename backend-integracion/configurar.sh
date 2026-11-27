#!/usr/bin/env bash
# Pide credenciales de aplicación y prepara el archivo .env local.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEMPLATE="${HERE}/.env.example"
ENV_FILE="${HERE}/.env"
command -v tailscale >/dev/null || { echo 'Falta Tailscale.' >&2; exit 1; }
tailscale status >/dev/null || { echo 'Tailscale no está conectado.' >&2; exit 1; }
if [[ -e "${ENV_FILE}" ]]; then
  read -r -p 'Ya existe .env. ¿Crear respaldo y reemplazarlo? (s/N) ' answer
  [[ "${answer}" =~ ^[sS]$ ]] || { echo 'No se modificó .env'; exit 0; }
  cp -p "${ENV_FILE}" "${ENV_FILE}.$(date +%Y%m%d%H%M%S).bak"
fi
read -r -s -p 'Contraseña de aplicación MariaDB: ' maria_pass; echo
read -r -s -p 'Contraseña de aplicación MongoDB: ' mongo_pass; echo
awk -v mp="${maria_pass}" -v xp="${mongo_pass}" '
  /^DB_PASS=/ {print "DB_PASS=" mp; next}
  /^MONGODB_PASSWORD=/ {print "MONGODB_PASSWORD=" xp; next}
  {print}
' "${TEMPLATE}" > "${ENV_FILE}"
chmod 0600 "${ENV_FILE}"
unset maria_pass mongo_pass
echo "Configuración creada. Ejecuta ./probar-conexiones.sh"

