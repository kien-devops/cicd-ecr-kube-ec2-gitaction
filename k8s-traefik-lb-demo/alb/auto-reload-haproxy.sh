#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [ -f "${ENV_FILE}" ]; then
  set -a
  # shellcheck disable=SC1090
  . "${ENV_FILE}"
  set +a
fi

INTERVAL_SECONDS="${ALB_AUTO_RELOAD_INTERVAL_SECONDS:-30}"
HAPROXY_CONFIG="${HAPROXY_CONFIG:-haproxy.cfg}"
HOST_CONFIG="${SCRIPT_DIR}/${HAPROXY_CONFIG}"

if [[ -z "${KUBECONFIG:-}" ]]; then
  if [[ -f "${HOME}/.kube/config" ]]; then
    export KUBECONFIG="${HOME}/.kube/config"
  elif [[ -n "${SUDO_USER:-}" && -f "/home/${SUDO_USER}/.kube/config" ]]; then
    export KUBECONFIG="/home/${SUDO_USER}/.kube/config"
  fi
fi

checksum() {
  if [[ -f "${HOST_CONFIG}" ]]; then
    sha256sum "${HOST_CONFIG}" | awk '{print $1}'
  else
    printf 'missing\n'
  fi
}

cd "${SCRIPT_DIR}"

echo "==> Watching Traefik nodes every ${INTERVAL_SECONDS}s"
last_loaded_checksum="$(checksum)"

while true; do
  if bash "${SCRIPT_DIR}/discover-traefik-nodes.sh"; then
    current_checksum="$(checksum)"

    if [[ "${last_loaded_checksum}" != "${current_checksum}" ]]; then
      echo "==> HAProxy config changed; validating and reloading"
      if RELOAD_SKIP_DISCOVER=true bash "${SCRIPT_DIR}/reload-haproxy.sh"; then
        last_loaded_checksum="${current_checksum}"
      else
        echo "==> Reload failed; will retry on the next loop" >&2
      fi
    else
      echo "==> HAProxy config unchanged"
    fi
  else
    echo "==> Discovery failed; keeping current HAProxy config" >&2
  fi

  sleep "${INTERVAL_SECONDS}"
done
