#!/usr/bin/env bash
# Recupera las cuentas de MongoDB en una intervención de mantenimiento.
set -euo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "Ejecuta como root" >&2; exit 1; }

SECURE=/etc/mongod.conf
BACKUP=/etc/mongod.conf.moodsitto-secure
SECRETS=/root/.moodsitto-secrets.env
cp -a "${SECURE}" "${BACKUP}"

cleanup() {
  if [[ -f "${BACKUP}" ]]; then
    systemctl stop mongod >/dev/null 2>&1 || true
    install -o root -g root -m 0644 "${BACKUP}" "${SECURE}"
    systemctl start mongod >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

systemctl stop mongod
sed '/^security:/,/^replication:/ { /^replication:/!d; }' "${BACKUP}" > "${SECURE}"
systemctl start mongod

for _ in {1..30}; do
  /usr/bin/mongosh --quiet --host 127.0.0.1 --eval 'db.hello().ok' >/dev/null 2>&1 && break
  sleep 1
done

umask 077
ADMIN_PASS=$(openssl rand -base64 36 | tr -d '\n')
APP_PASS=$(openssl rand -base64 36 | tr -d '\n')
export ADMIN_PASS APP_PASS
printf 'MONGO_ADMIN_USER=moodsitto_admin\nMONGO_ADMIN_PASS=%s\nMONGO_APP_USER=moodsitto_app\nMONGO_APP_PASS=%s\n' \
  "${ADMIN_PASS}" "${APP_PASS}" > "${SECRETS}"
chmod 0600 "${SECRETS}"

/usr/bin/mongosh --quiet --host 127.0.0.1 admin --eval '
  if (db.getUser("moodsitto_admin")) {
    db.updateUser("moodsitto_admin", {pwd:process.env.ADMIN_PASS,roles:[{role:"root",db:"admin"}]});
  } else {
    db.createUser({user:"moodsitto_admin",pwd:process.env.ADMIN_PASS,roles:[{role:"root",db:"admin"}]});
  }'
/usr/bin/mongosh --quiet --host 127.0.0.1 moodsitto --eval '
  if (db.getUser("moodsitto_app")) {
    db.updateUser("moodsitto_app", {pwd:process.env.APP_PASS,roles:[{role:"readWrite",db:"moodsitto"}]});
  } else {
    db.createUser({user:"moodsitto_app",pwd:process.env.APP_PASS,roles:[{role:"readWrite",db:"moodsitto"}]});
  }'

systemctl stop mongod
install -o root -g root -m 0644 "${BACKUP}" "${SECURE}"
rm -f "${BACKUP}"
systemctl start mongod
trap - EXIT

for _ in {1..30}; do
  state=$(/usr/bin/mongosh --quiet --host 127.0.0.1 \
    -u moodsitto_admin -p "${ADMIN_PASS}" --authenticationDatabase admin \
    --eval 'db.hello().isWritablePrimary' 2>/dev/null || true)
  [[ "${state}" == "true" ]] && break
  sleep 1
done
[[ "${state}" == "true" ]] || { echo "Falló la autenticación segura" >&2; exit 1; }
echo "Usuarios recuperados y autenticación verificada."
