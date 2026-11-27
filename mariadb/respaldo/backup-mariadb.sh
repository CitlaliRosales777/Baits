#!/usr/bin/env bash
# Respalda el esquema moodsitto en HP y comprueba la integridad del archivo.
set -euo pipefail
DEST=/srv/storage/moodsitto/backups/mariadb
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
FILE="${DEST}/moodsitto-${STAMP}.sql.gz"
install -d -o root -g mysql -m 0750 "${DEST}"

/usr/bin/mariadb-dump --single-transaction --routines --events --triggers \
  --default-character-set=utf8mb4 moodsitto | gzip -9 > "${FILE}"
gzip -t "${FILE}"
sha256sum "${FILE}" > "${FILE}.sha256"
find "${DEST}" -type f -name 'moodsitto-*.sql.gz*' -mtime +7 -delete
echo "Backup MariaDB verificado: ${FILE}"

