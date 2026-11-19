#!/usr/bin/env bash
set -euo pipefail
source /root/.moodsitto-secrets.env
/usr/bin/mongosh --quiet 'mongodb://100.94.145.63:27017,100.89.172.17:27017/admin?replicaSet=rsMoodsitto&serverSelectionTimeoutMS=10000' \
  -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASS}" --authenticationDatabase admin \
  --eval 'printjson({hello:db.hello(),members:rs.status().members.map(m=>({name:m.name,state:m.stateStr,health:m.health,lastHeartbeatMessage:m.lastHeartbeatMessage}))})'
