#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ejecuta como root." >&2
  exit 1
fi

MONGOSH=/usr/bin/mongosh
SECRETS=/root/.moodsitto-secrets.env

if ! "${MONGOSH}" --quiet --host 127.0.0.1 --eval 'db.hello().setName' | grep -qx 'rsMoodsitto'; then
  "${MONGOSH}" --quiet --host 127.0.0.1 --eval \
    'rs.initiate({_id:"rsMoodsitto",members:[{_id:0,host:"100.94.145.63:27017",priority:2,votes:1}]})'
fi

state=false
for _ in {1..30}; do
  state=$("${MONGOSH}" --quiet --host 127.0.0.1 --eval 'db.hello().isWritablePrimary' 2>/dev/null || true)
  [[ "${state}" == "true" ]] && break
  sleep 2
done
[[ "${state}" == "true" ]] || { echo "El nodo no llegó a PRIMARY" >&2; exit 1; }

if [[ ! -s "${SECRETS}" ]]; then
  umask 077
  ADMIN_PASS=$(openssl rand -base64 36 | tr -d '\n')
  APP_PASS=$(openssl rand -base64 36 | tr -d '\n')
  export ADMIN_PASS APP_PASS

  "${MONGOSH}" --quiet --host 127.0.0.1 admin --eval \
    'db.createUser({user:"moodsitto_admin",pwd:process.env.ADMIN_PASS,roles:[{role:"root",db:"admin"}]})'
  "${MONGOSH}" --quiet --host 127.0.0.1 moodsitto --eval \
    'db.createUser({user:"moodsitto_app",pwd:process.env.APP_PASS,roles:[{role:"readWrite",db:"moodsitto"}]})'

  printf 'MONGO_ADMIN_USER=moodsitto_admin\nMONGO_ADMIN_PASS=%s\nMONGO_APP_USER=moodsitto_app\nMONGO_APP_PASS=%s\n' \
    "${ADMIN_PASS}" "${APP_PASS}" > "${SECRETS}"
  chmod 0600 "${SECRETS}"
fi

# shellcheck disable=SC1090
source "${SECRETS}"
"${MONGOSH}" --quiet --host 127.0.0.1 \
  -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASS}" --authenticationDatabase admin \
  --eval 'const s=rs.status(); printjson({set:s.set,myState:s.myState,primary:db.hello().primary,members:s.members.length})'
