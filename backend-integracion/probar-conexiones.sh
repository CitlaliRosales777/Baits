#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
[[ -f "${HERE}/.env" ]] || { echo 'Falta .env. Ejecuta configurar.sh.' >&2; exit 1; }
set -a; source "${HERE}/.env"; set +a
ok(){ printf '[OK] %s\n' "$1"; }
command -v tailscale >/dev/null && tailscale status >/dev/null || { echo 'No tienes acceso a Tailscale.' >&2; exit 1; }
ok 'Conectividad Tailscale'
command -v mariadb >/dev/null || { echo 'Falta el cliente mariadb.' >&2; exit 1; }
export MYSQL_PWD="${DB_PASS}"
corr=$(cat /proc/sys/kernel/random/uuid)
result=$(mariadb -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" "${DB_NAME}" -NBe "START TRANSACTION; INSERT INTO auditoria_eventos(actor_id_user,accion,recurso,resultado,correlacion_id) VALUES(NULL,'prueba_integracion','backend','ok','${corr}'); SELECT COUNT(*) FROM auditoria_eventos WHERE correlacion_id='${corr}'; ROLLBACK;")
unset MYSQL_PWD
[[ "${result##*$'\n'}" == 1 ]] || { echo 'Falló MariaDB.' >&2; exit 1; }
ok 'Servidor, autenticación, lectura y escritura MariaDB'
command -v mongosh >/dev/null || { echo 'Falta mongosh.' >&2; exit 1; }
mcorr=$(cat /proc/sys/kernel/random/uuid)
uri="mongodb://${MONGODB_HOSTS}/${MONGODB_DATABASE}?replicaSet=${MONGODB_REPLICA_SET}&authSource=${MONGODB_AUTH_SOURCE}&retryWrites=true&w=majority"
js="const c='${mcorr}'; const h=db.hello(); if(h.setName!=='${MONGODB_REPLICA_SET}') throw new Error('Replica set incorrecto'); db.auditoria_documental.insertOne({actor_id_user:null,accion:'prueba_integracion',recurso:'backend',recurso_id:null,resultado:'ok',correlacion_id:c,metadata_segura:{datos:'sinteticos'},created_at:new Date()}); if(db.auditoria_documental.countDocuments({correlacion_id:c})!==1) throw new Error('Lectura fallida'); db.auditoria_documental.deleteOne({correlacion_id:c}); print('TEST_OK');"
result=$(mongosh --quiet "${uri}" -u "${MONGODB_USER}" -p "${MONGODB_PASSWORD}" --eval "${js}")
[[ "${result##*$'\n'}" == TEST_OK ]] || { echo 'Falló MongoDB.' >&2; exit 1; }
ok 'Servidor, autenticación, replica set, lectura y escritura MongoDB'
ok 'Permisos de aplicación'
ok 'Integración preparada'
