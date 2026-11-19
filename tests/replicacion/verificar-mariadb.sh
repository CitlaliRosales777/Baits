#!/usr/bin/env bash
set -euo pipefail
CORR=${1:?Uso: verificar-mariadb.sh UUID}
[[ "${CORR}" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo "UUID inválido" >&2; exit 1; }
sudo -n mariadb -NBe "SELECT COUNT(*) FROM moodsitto.auditoria_eventos WHERE correlacion_id='${CORR}'"
