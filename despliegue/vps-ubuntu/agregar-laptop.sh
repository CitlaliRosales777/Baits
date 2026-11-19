#!/usr/bin/env bash
set -euo pipefail
source /root/.moodsitto-secrets.env
AUTH=(-u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASS}" --authenticationDatabase admin)
MONGO=(/usr/bin/mongosh --quiet 'mongodb://100.94.145.63:27017,100.89.172.17:27017/admin?replicaSet=rsMoodsitto' "${AUTH[@]}")
"${MONGO[@]}" --eval '
  const host="100.86.5.50:27017";
  const cfg=rs.conf();
  if (!cfg.members.some(m=>m.host===host)) printjson(rs.add({host:host,priority:0,votes:1}));
  else print("El miembro ya existe");'
for _ in {1..90}; do
  state=$("${MONGO[@]}" --eval 'const m=rs.status().members.find(x=>x.name==="100.86.5.50:27017"); m?m.stateStr:"AUSENTE";' 2>/dev/null || true)
  [[ "${state}" == "SECONDARY" ]] && break
  sleep 2
done
[[ "${state}" == "SECONDARY" ]] || { echo "Estado final: ${state}" >&2; exit 1; }

key="prueba-laptop-$(date +%s)"
"${MONGO[@]}" --eval "db.getSiblingDB('moodsitto').auditoria_documental.insertOne({actor_id_user:null,accion:'prueba_replicacion_laptop',recurso:'infraestructura',recurso_id:null,resultado:'ok',correlacion_id:'${key}',metadata_segura:{datos:'sinteticos'},created_at:new Date()},{writeConcern:{w:'majority',wtimeout:15000}})" >/dev/null
count=$(/usr/bin/mongosh --quiet 'mongodb://100.86.5.50:27017/moodsitto?directConnection=true&readPreference=secondary' "${AUTH[@]}" --eval "db.auditoria_documental.countDocuments({correlacion_id:'${key}'})")
[[ "${count}" == "1" ]] || { echo "Documento no visible en laptop" >&2; exit 1; }
"${MONGO[@]}" --eval "db.getSiblingDB('moodsitto').auditoria_documental.deleteOne({correlacion_id:'${key}'},{writeConcern:{w:'majority'}})" >/dev/null
"${MONGO[@]}" --eval 'printjson(rs.status().members.map(m=>({name:m.name,state:m.stateStr,health:m.health,priority:rs.conf().members.find(c=>c.host===m.name).priority})))'
