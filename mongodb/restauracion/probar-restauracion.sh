#!/usr/bin/env bash
# Valida la recuperación de las colecciones de moodsitto en el espacio de prueba.
set -euo pipefail
BACKUP=${1:?Uso: probar-restauracion.sh archivo.archive.gz}
source /root/.moodsitto-secrets.env
AUTH=(--username "${MONGO_ADMIN_USER}" --password "${MONGO_ADMIN_PASS}" --authenticationDatabase admin)

[[ -s "${BACKUP}" ]] || { echo "Respaldo inexistente" >&2; exit 1; }
/usr/bin/mongorestore --host 127.0.0.1 "${AUTH[@]}" --archive="${BACKUP}" --gzip \
  --nsInclude='moodsitto.*' --nsFrom='moodsitto.*' --nsTo='moodsitto_restore_test.*' --drop

result=$(/usr/bin/mongosh --quiet --host 127.0.0.1 \
  -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASS}" --authenticationDatabase admin \
  moodsitto_restore_test --eval 'print(db.getCollectionNames().length)')
[[ "${result}" -eq 4 ]] || { echo "Se esperaban 4 colecciones; se obtuvieron ${result}" >&2; exit 1; }

/usr/bin/mongosh --quiet --host 127.0.0.1 \
  -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASS}" --authenticationDatabase admin \
  moodsitto_restore_test --eval 'db.dropDatabase()' >/dev/null
echo "Restauración MongoDB aislada aprobada: ${result} colecciones."
