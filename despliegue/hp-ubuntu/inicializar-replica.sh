#!/usr/bin/env bash
set -euo pipefail

SEED=/tmp/moodsitto-seed.sql
REPL=/tmp/configurar-replica.sql
[[ -s "${SEED}" && -s "${REPL}" ]] || { echo "Faltan archivos de inicialización" >&2; exit 1; }

sudo -n mariadb -e 'STOP SLAVE' 2>/dev/null || true
sudo -n mariadb < "${SEED}"
sudo -n mariadb < "${REPL}"
rm -f "${SEED}" "${REPL}"

for _ in {1..30}; do
  status=$(sudo -n mariadb -NBe "SELECT CONCAT(IFNULL(SLAVE_IO_RUNNING,''),'|',IFNULL(SLAVE_SQL_RUNNING,'')) FROM information_schema.SLAVE_STATUS" 2>/dev/null || true)
  [[ "${status}" == "Yes|Yes" ]] && break
  sleep 2
done

sudo -n mariadb -e 'SHOW ALL SLAVES STATUS\G' | grep -E 'Slave_(IO|SQL)_Running:|Seconds_Behind_Master:|Gtid_IO_Pos:|Last_(IO|SQL)_Error:'
[[ "${status}" == "Yes|Yes" ]] || exit 1
