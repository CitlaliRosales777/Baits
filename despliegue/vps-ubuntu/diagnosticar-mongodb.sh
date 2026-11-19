#!/usr/bin/env bash
set -euo pipefail
source /root/.moodsitto-secrets.env
AUTH=(-u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASS}" --authenticationDatabase admin)
echo STATUS
/usr/bin/mongosh --quiet --host 127.0.0.1 "${AUTH[@]}" --eval 'printjson(rs.status().members.map(m=>({name:m.name,state:m.stateStr,health:m.health,optimeDate:m.optimeDate,lastHeartbeatMessage:m.lastHeartbeatMessage})))'
echo SECONDARY_READ
/usr/bin/mongosh --quiet 'mongodb://100.89.172.17:27017/moodsitto?directConnection=true&readPreference=secondary' "${AUTH[@]}" --eval 'printjson(db.auditoria_documental.findOne({correlacion_id:"prueba-replicacion-2026-11-19"},{_id:0,accion:1,resultado:1,correlacion_id:1}))'
