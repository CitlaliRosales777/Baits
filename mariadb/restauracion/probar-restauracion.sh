#!/usr/bin/env bash
# Importa una copia de moodsitto en el esquema de prueba y valida sus tablas.
set -euo pipefail
BACKUP=${1:?Uso: probar-restauracion.sh archivo.sql.gz}
TEST_DB=moodsitto_restore_test
[[ -s "${BACKUP}" ]] || { echo "Respaldo inexistente" >&2; exit 1; }
gzip -t "${BACKUP}"
mariadb --init-command='SET SESSION sql_log_bin=0' -e "DROP DATABASE IF EXISTS ${TEST_DB}; CREATE DATABASE ${TEST_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
trap 'mariadb --init-command="SET SESSION sql_log_bin=0" -e "DROP DATABASE IF EXISTS moodsitto_restore_test"' EXIT
gzip -dc "${BACKUP}" | mariadb --init-command='SET SESSION sql_log_bin=0' "${TEST_DB}"
count=$(mariadb -NBe "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${TEST_DB}'")
[[ "${count}" -eq 23 ]] || { echo "Se esperaban 23 tablas; se encontraron ${count}" >&2; exit 1; }
echo "Restauración aislada aprobada: ${count} tablas."
