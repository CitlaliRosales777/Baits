#!/usr/bin/env bash
# Respalda por separado la aplicación y APIcore desde la réplica HP.
set -euo pipefail
DEST=/srv/storage/moodsitto/backups/mariadb
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
install -d -o root -g mysql -m 0750 "${DEST}"
umask 077
for esquema in moodsitto apicore; do
  archivo="${DEST}/${esquema}-${STAMP}.sql.gz"
  temporal=$(mktemp "${DEST}/.${esquema}-XXXXXX")
  trap 'rm -f -- "$temporal"' EXIT
  /usr/bin/mariadb-dump --single-transaction --routines --events --triggers \
    --default-character-set=utf8mb4 "${esquema}" | gzip -9 > "${temporal}"
  # Publica la copia solo después de comprobar que el archivo puede leerse.
  gzip -t "${temporal}"
  mv -- "${temporal}" "${archivo}"
  trap - EXIT
  sha256sum "${archivo}" > "${archivo}.sha256"
  echo "Respaldo verificado de ${esquema}: ${archivo}"
done
find "${DEST}" -type f \( -name 'moodsitto-*.sql.gz*' -o -name 'apicore-*.sql.gz*' \) -mtime +7 -delete

