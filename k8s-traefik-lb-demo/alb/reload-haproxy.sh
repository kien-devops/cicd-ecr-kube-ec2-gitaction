#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="${HAPROXY_CONTAINER_NAME:-haproxy-alb}"
CONTAINER_CONFIG="/usr/local/etc/haproxy/haproxy.cfg"
HOST_CONFIG="${SCRIPT_DIR}/haproxy.cfg"

if [[ -z "${KUBECONFIG:-}" ]]; then
  if [[ -f "${HOME}/.kube/config" ]]; then
    export KUBECONFIG="${HOME}/.kube/config"
  elif [[ -n "${SUDO_USER:-}" && -f "/home/${SUDO_USER}/.kube/config" ]]; then
    export KUBECONFIG="/home/${SUDO_USER}/.kube/config"
  fi
fi

cd "${SCRIPT_DIR}"

compose_up() {
  if sudo docker compose version >/dev/null 2>&1; then
    sudo docker compose up -d --force-recreate
  else
    sudo docker-compose up -d --force-recreate
  fi
}

echo "==> Discovering Traefik nodes and regenerating haproxy.cfg"
bash "${SCRIPT_DIR}/discover-traefik-nodes.sh"

echo "==> Checking HAProxy container"
if ! sudo docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "==> HAProxy container is not running, starting it"
  compose_up
else
  echo "==> Checking mounted config path"
  MOUNT_SOURCE="$(
    sudo docker inspect "${CONTAINER_NAME}" \
      --format '{{range .Mounts}}{{if eq .Destination "/usr/local/etc/haproxy/haproxy.cfg"}}{{.Source}}{{end}}{{end}}'
  )"

  if [[ "${MOUNT_SOURCE}" != "${HOST_CONFIG}" ]]; then
    echo "==> HAProxy container is using wrong config mount"
    echo "    container mount: ${MOUNT_SOURCE}"
    echo "    expected mount : ${HOST_CONFIG}"
    echo "==> Recreating container once to fix bind mount"
    compose_up
  else
    echo "==> Validating HAProxy config"
    sudo docker exec "${CONTAINER_NAME}" haproxy -c -f "${CONTAINER_CONFIG}"

    echo "==> Reloading HAProxy gracefully"
    sudo docker kill -s USR2 "${CONTAINER_NAME}" >/dev/null
  fi
fi

echo "==> HAProxy backend servers on host"
grep '^[[:space:]]*server worker' "${HOST_CONFIG}" || true

echo "==> HAProxy backend servers in container"
sudo docker exec "${CONTAINER_NAME}" grep '^[[:space:]]*server worker' "${CONTAINER_CONFIG}" || true

echo "==> HAProxy logs"
sudo docker logs --tail 80 "${CONTAINER_NAME}"