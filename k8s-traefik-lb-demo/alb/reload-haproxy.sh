#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="${HAPROXY_CONTAINER_NAME:-haproxy-alb}"
CONTAINER_CONFIG="/usr/local/etc/haproxy/haproxy.cfg"

bash "${SCRIPT_DIR}/discover-traefik-nodes.sh"

if sudo docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "==> Validating HAProxy config"
  sudo docker exec "${CONTAINER_NAME}" haproxy -c -f "${CONTAINER_CONFIG}"

  echo "==> Reloading HAProxy gracefully"
  sudo docker kill -s USR2 "${CONTAINER_NAME}" >/dev/null

  echo "==> HAProxy logs"
  sudo docker logs --tail 50 "${CONTAINER_NAME}"
else
  echo "${CONTAINER_NAME} is not running. Start it with: sudo docker compose up -d"
fi
