#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="${HAPROXY_CONTAINER_NAME:-haproxy-alb}"

# Ensure kubectl can find the kubeconfig when called via sudo or automation.
if [[ -z "${KUBECONFIG:-}" ]]; then
  if [[ -f "${HOME}/.kube/config" ]]; then
    export KUBECONFIG="${HOME}/.kube/config"
  elif [[ -n "${SUDO_USER:-}" && -f "/home/${SUDO_USER}/.kube/config" ]]; then
    export KUBECONFIG="/home/${SUDO_USER}/.kube/config"
  fi
fi

cd "${SCRIPT_DIR}"

echo "==> Discovering Traefik nodes and regenerating haproxy.cfg"
bash "${SCRIPT_DIR}/discover-traefik-nodes.sh"

echo "==> Recreating HAProxy container"

if docker compose version >/dev/null 2>&1; then
  sudo docker-compose up -d --force-recreate
else
  sudo docker-compose up -d --force-recreate
fi

echo "==> HAProxy container status"
sudo docker ps --filter "name=${CONTAINER_NAME}"

echo "==> HAProxy logs"
sudo docker logs --tail 80 "${CONTAINER_NAME}"