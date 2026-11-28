#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ejecuta este script con sudo." >&2
  exit 1
fi

if [[ -z "${LAB_AGENT_TOKEN:-}" || ${#LAB_AGENT_TOKEN} -lt 20 ]]; then
  echo "Define LAB_AGENT_TOKEN con al menos 20 caracteres." >&2
  exit 1
fi

PROJECT_PATH="${PROJECT_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NODE_BIN="$(command -v node)"
AGENT_PATH="${PROJECT_PATH}/agent/server.js"
AGENT_ENV="${PROJECT_PATH}/agent/.env"
MONGO_SERVICE="${MONGODB_SERVICE:-mongod}"

systemctl enable --now tailscaled
systemctl enable --now "${MONGO_SERVICE}"

printf 'AGENT_HOST=0.0.0.0\nAGENT_PORT=4318\nLAB_AGENT_TOKEN=%s\nMONGODB_SERVICE=%s\n' \
  "${LAB_AGENT_TOKEN}" "${MONGO_SERVICE}" > "${AGENT_ENV}"
chmod 600 "${AGENT_ENV}"

cat > /etc/systemd/system/moodsitto-lab-agent.service <<EOF
[Unit]
Description=Moodsitto Resilience Lab Agent
After=network-online.target tailscaled.service ${MONGO_SERVICE}.service
Wants=network-online.target tailscaled.service

[Service]
Type=simple
User=root
WorkingDirectory=${PROJECT_PATH}
ExecStart=${NODE_BIN} ${AGENT_PATH}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now moodsitto-lab-agent

echo "Nodo Linux preparado. Tailscale, MongoDB y el agente se reconectaran automaticamente."
