#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source /root/.moodsitto-secrets.env

AUTH=(-u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASS}" --authenticationDatabase admin)
/usr/bin/mongosh --quiet --host 127.0.0.1 "${AUTH[@]}" /tmp/01-modelo-hibrido.js

/usr/bin/mongosh --quiet --host 127.0.0.1 "${AUTH[@]}" moodsitto --eval '
  const key="prueba-replicacion-2026-11-19";
  printjson(db.auditoria_documental.updateOne(
    {correlacion_id:key},
    {$setOnInsert:{actor_id_user:null,accion:"prueba_replicacion",recurso:"infraestructura",recurso_id:null,resultado:"ok",correlacion_id:key,metadata_segura:{datos:"sinteticos"},created_at:new Date()}},
    {upsert:true,writeConcern:{w:"majority",wtimeout:15000}}
  ));'

for _ in {1..30}; do
  count=$(/usr/bin/mongosh --quiet 'mongodb://100.89.172.17:27017/moodsitto?directConnection=true&readPreference=secondary' "${AUTH[@]}" --eval \
    'db.auditoria_documental.countDocuments({correlacion_id:"prueba-replicacion-2026-11-19"})' 2>/dev/null || true)
  [[ "${count}" == "1" ]] && break
  sleep 1
done
[[ "${count}" == "1" ]] || { echo "Documento no visible en SECONDARY" >&2; exit 1; }
echo "Documento sintético verificado en Windows fijo SECONDARY."
