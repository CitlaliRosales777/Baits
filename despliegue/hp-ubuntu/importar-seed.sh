#!/usr/bin/env bash
# Importa el respaldo inicial en HP y utiliza la posición GTID indicada.
set -euo pipefail
GTID=${1:?Uso: importar-seed.sh POSICION_GTID}
[[ "${GTID}" =~ ^[0-9-]+(,[0-9-]+)*$ ]] || { echo "GTID inválido" >&2; exit 1; }
[[ -s /tmp/moodsitto-seed.sql ]] || { echo "Falta seed" >&2; exit 1; }
sudo -n mariadb -e 'STOP SLAVE' 2>/dev/null || true
sudo -n mariadb -e 'RESET SLAVE ALL' 2>/dev/null || true
sudo -n mariadb --init-command='SET SESSION sql_log_bin=0' < /tmp/moodsitto-seed.sql
sudo -n mariadb -e "SET GLOBAL gtid_slave_pos='${GTID}'"
rm -f /tmp/moodsitto-seed.sql
sudo -n mariadb -NBe "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodsitto'; SELECT @@gtid_slave_pos"
