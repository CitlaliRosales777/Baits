#!/usr/bin/env bash
set -euo pipefail

api_url=${MOODSITTO_API_URL:-https://api.lvltechmx.com}
result=$(curl --fail --silent --show-error --max-time 15 "${api_url%/}/api/healthcheck")
[[ "${result}" == *'"status":"ok"'* ]] || { echo 'La API respondió con un estado inesperado.' >&2; exit 1; }

echo '[OK] DNS y conexión a Internet'
echo '[OK] Certificado HTTPS válido'
echo '[OK] API pública de Moodsitto disponible'
echo "URL: ${api_url%/}"

