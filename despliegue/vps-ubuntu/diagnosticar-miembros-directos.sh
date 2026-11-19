#!/usr/bin/env bash
set -euo pipefail
source /root/.moodsitto-secrets.env
for host in 100.94.145.63 100.89.172.17 100.86.5.50; do
  echo "--- ${host} ---"
  /usr/bin/mongosh --quiet "mongodb://${host}:27017/admin?directConnection=true&serverSelectionTimeoutMS=5000" \
    -u "${MONGO_ADMIN_USER}" -p "${MONGO_ADMIN_PASS}" --authenticationDatabase admin \
    --eval 'const h=db.hello(); printjson({me:h.me,primary:h.primary,setName:h.setName,isWritablePrimary:h.isWritablePrimary,secondary:h.secondary,hosts:h.hosts,passives:h.passives});' || true
done
