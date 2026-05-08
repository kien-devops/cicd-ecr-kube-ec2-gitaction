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

echo "==> Discovering Traefik nodes and regenerating haproxy.cfg"
bash "${SCRIPT_DIR}/discover-traefik-nodes.sh"

echo "==> Checking HAProxy container"
if ! sudo docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "HAProxy container is not running. Refusing to start it to avoid unintended restart."
  exit 1
fi

echo "==> Checking mounted config path"
MOUNT_SOURCE="$(
  sudo docker inspect "${CONTAINER_NAME}" \
    --format '{{range .Mounts}}{{if eq .Destination "/usr/local/etc/haproxy/haproxy.cfg"}}{{.Source}}{{end}}{{end}}'
)"

if [[ -n "${MOUNT_SOURCE}" ]]; then
  echo "==> Using mounted host config: ${MOUNT_SOURCE}"
  HOST_CONFIG="${MOUNT_SOURCE}"
fi

echo "==> Config is updated on host bind mount; no docker cp needed"

echo "==> Validating HAProxy config"
sudo docker exec "${CONTAINER_NAME}" haproxy -c -f "${CONTAINER_CONFIG}"

echo "==> Reloading HAProxy gracefully with USR2"
sudo docker kill -s USR2 "${CONTAINER_NAME}" >/dev/null

echo "==> Waiting for container config to match host config"
for _ in {1..10}; do
  if cmp -s "${HOST_CONFIG}" <(sudo docker exec "${CONTAINER_NAME}" cat "${CONTAINER_CONFIG}"); then
    echo "==> Container config matches host config"
    break
  fi
  sleep 1
done

echo "==> HAProxy backend servers on host"
grep '^[[:space:]]*server worker' "${HOST_CONFIG}" || true

echo "==> HAProxy backend servers in container"
sudo docker exec "${CONTAINER_NAME}" grep '^[[:space:]]*server worker' "${CONTAINER_CONFIG}" || true

echo "==> HAProxy logs"
sudo docker logs --tail 80 "${CONTAINER_NAME}"