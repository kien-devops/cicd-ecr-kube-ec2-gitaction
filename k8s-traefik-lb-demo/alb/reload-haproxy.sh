#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="${HAPROXY_CONTAINER_NAME:-haproxy-alb}"
CONTAINER_CONFIG="/usr/local/etc/haproxy/haproxy.cfg"

# Ensure kubectl can find the kubeconfig when called via sudo or automation.
# If KUBECONFIG is not set, try common locations.
if [[ -z "${KUBECONFIG:-}" ]]; then
  if [[ -f "${HOME}/.kube/config" ]]; then
    export KUBECONFIG="${HOME}/.kube/config"
  elif [[ -n "${SUDO_USER:-}" ]] && [[ -f "/home/${SUDO_USER}/.kube/config" ]]; then
    export KUBECONFIG="/home/${SUDO_USER}/.kube/config"
  fi
fi

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
