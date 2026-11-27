#!/usr/bin/env bash
# Incorpora el Windows fijo al conjunto de réplicas de MongoDB.
set -euo pipefail

# shellcheck disable=SC1091
source /root/.moodsitto-secrets.env
MONGO=(/usr/bin/mongosh --quiet --host 127.0.0.1 -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASS}" --authenticationDatabase admin)

"${MONGO[@]}" --eval '
  const host="100.89.172.17:27017";
  const cfg=rs.conf();
  if (!cfg.members.some(m => m.host === host)) {
    printjson(rs.add({host:host,priority:1,votes:1}));
  } else {
    print("El miembro ya existe");
  }'

for _ in {1..60}; do
  state=$("${MONGO[@]}" --eval '
    const m=rs.status().members.find(x => x.name === "100.89.172.17:27017");
    m ? m.stateStr : "AUSENTE";' 2>/dev/null || true)
  [[ "${state}" == "SECONDARY" ]] && break
  sleep 2
done
[[ "${state}" == "SECONDARY" ]] || { echo "Estado final: ${state}" >&2; exit 1; }
"${MONGO[@]}" --eval 'printjson(rs.status().members.map(m=>({name:m.name,state:m.stateStr,health:m.health})))'
