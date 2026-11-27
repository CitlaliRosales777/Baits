#!/usr/bin/env bash
# Valida la recuperación de las colecciones de moodsitto en el espacio de prueba.
set -euo pipefail
BACKUP=${1:?Uso: probar-restauracion.sh archivo.archive.gz}
source /root/.moodsitto-secrets.env
AUTH=(--username "${MONGO_ADMIN_USER}" --password "${MONGO_ADMIN_PASS}" --authenticationDatabase admin)

[[ -s "${BACKUP}" ]] || { echo "Respaldo inexistente" >&2; exit 1; }
if [[ -f "${BACKUP}.sha256" ]]; then
  sha256sum --check --status "${BACKUP}.sha256"
fi

# Cada ejecución recupera los datos en su propio espacio de prueba.
RESTORE_DB="moodsitto_restore_test_${BASHPID}_${RANDOM}_${RANDOM}"
mongo_test() {
  /usr/bin/mongosh --quiet --host 127.0.0.1 "${AUTH[@]}" "${RESTORE_DB}" "$@"
}
mongo_test --eval 'if (db.getCollectionNames().length) quit(1)'
trap 'mongo_test --eval "if (!db.dropDatabase().ok) quit(1)" >/dev/null' EXIT
/usr/bin/mongorestore --host 127.0.0.1 "${AUTH[@]}" --archive="${BACKUP}" --gzip \
  --nsInclude='moodsitto.*' --nsFrom='moodsitto.*' --nsTo="${RESTORE_DB}.*"

mongo_test --eval '
  const names = db.getCollectionNames();
  const required = ["catalogo_emociones", "registros_emocionales", "resumenes_emocionales", "auditoria_documental"];
  const missing = required.filter(name => !names.includes(name));
  if (missing.length) {
    print("Faltan las colecciones: " + missing.join(", "));
    quit(1);
  }
  print("Restauración MongoDB aislada aprobada: 4 colecciones base.");
  print("Historial APIcore: " + (names.includes("historial_emociones_apicore") ? "presente" : "ausente en esta copia"));
'
