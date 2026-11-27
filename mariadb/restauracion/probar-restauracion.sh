#!/usr/bin/env bash
# Importa una copia en un esquema de prueba y valida las tablas del origen correspondiente.
set -euo pipefail
BACKUP=${1:?Uso: probar-restauracion.sh archivo.sql.gz}
case "${BACKUP##*/}" in
  moodsitto-*.sql.gz) esquema=moodsitto ;;
  apicore-*.sql.gz) esquema=apicore ;;
  *) echo 'Nombre de respaldo desconocido.' >&2; exit 1 ;;
esac
# Cada prueba reserva su propio esquema para preservar otras restauraciones.
TEST_DB="moodsitto_restore_test_${BASHPID}_${RANDOM}"
[[ -s "${BACKUP}" ]] || { echo "Respaldo inexistente" >&2; exit 1; }
gzip -t "${BACKUP}"
if [[ -f "${BACKUP}.sha256" ]]; then sha256sum --check --status "${BACKUP}.sha256"; fi
mariadb --init-command='SET SESSION sql_log_bin=0' -e "CREATE DATABASE ${TEST_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
trap 'mariadb --init-command="SET SESSION sql_log_bin=0" -e "DROP DATABASE ${TEST_DB}"' EXIT
gzip -dc "${BACKUP}" | mariadb --init-command='SET SESSION sql_log_bin=0' "${TEST_DB}"
# Tanto las copias antiguas como las nuevas deben conservar las 23 tablas base.
if [[ "${esquema}" == moodsitto ]]; then
  count=$(mariadb -NBe "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${TEST_DB}' AND table_name<>'login_intentos'")
  [[ "${count}" -eq 23 ]] || { echo "Se esperaban 23 tablas; se encontraron ${count}" >&2; exit 1; }
  echo "Restauración aislada aprobada: ${count} tablas base."
else
  mariadb "${TEST_DB}" -e 'SELECT COUNT(*) AS cuentas_recuperadas FROM users; SELECT COUNT(*) AS recordatorios_recuperados FROM tablero_recordatorios; SELECT 1 FROM users_tokens LIMIT 0; SELECT 1 FROM moods LIMIT 0; SELECT 1 FROM `example` LIMIT 0;'
  echo 'Restauración aislada de APIcore aprobada.'
fi
