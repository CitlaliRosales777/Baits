#!/usr/bin/env bash
set -euo pipefail
umask 077
source /root/.moodsitto-secrets.env
DEST=/var/backups/moodsitto/mongodb
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
FILE="${DEST}/moodsitto-${STAMP}.archive.gz"
install -d -o root -g root -m 0700 "${DEST}"

/usr/bin/mongodump --host 127.0.0.1 --port 27017 \
  --username "${MONGO_ADMIN_USER}" --password "${MONGO_ADMIN_PASS}" \
  --authenticationDatabase admin --oplog \
  --archive="${FILE}" --gzip

test -s "${FILE}"
/usr/bin/mongorestore --archive="${FILE}" --gzip --dryRun >/dev/null
sha256sum "${FILE}" > "${FILE}.sha256"
find "${DEST}" -type f -name 'moodsitto-*.archive.gz*' -mtime +7 -delete
echo "Backup MongoDB verificado: ${FILE}"

