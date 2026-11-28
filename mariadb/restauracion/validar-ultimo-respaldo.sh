#!/usr/bin/env bash
# Entrada restringida para ejecutar las restauraciones aisladas desde el panel.
set -euo pipefail
[[ $# -eq 1 ]] || exit 2
case "$1" in moodsitto|apicore) esquema=$1 ;; *) exit 2 ;; esac
directorio=/srv/storage/moodsitto/backups/mariadb
backup=$(find "$directorio" -maxdepth 1 -type f -name "${esquema}-*.sql.gz" -print | sort | tail -n 1)
[[ -n "$backup" && -s "$backup" && -f "$backup.sha256" ]] || {
  echo "Falta un respaldo verificable de $esquema." >&2
  exit 3
}
exec /usr/local/libexec/moodsitto-probar-restauracion "$backup"
