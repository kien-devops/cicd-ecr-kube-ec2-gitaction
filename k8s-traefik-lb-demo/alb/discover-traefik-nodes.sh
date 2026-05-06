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

: "${ALB_DOMAIN:=benhvien.teamdevops.shop}"
: "${TRAEFIK_HTTP_NODEPORT:=30080}"
: "${TRAEFIK_HTTPS_NODEPORT:=30443}"
: "${KUBE_NODE_SELECTOR:=}"
: "${DISCOVER_TRAEFIK_PODS:=true}"
: "${TRAEFIK_NAMESPACE:=traefik}"
: "${TRAEFIK_POD_SELECTOR:=app=traefik}"
: "${KUBE_NODE_ADDRESS_TYPE:=InternalIP}"
: "${HAPROXY_CONFIG:=haproxy.cfg}"

command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl is required for ALB node discovery" >&2
  exit 1
}

node_args=(get nodes)
if [ -n "${KUBE_NODE_SELECTOR}" ]; then
  node_args+=(-l "${KUBE_NODE_SELECTOR}")
fi

mapfile -t all_nodes < <(kubectl "${node_args[@]}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

if [ "${DISCOVER_TRAEFIK_PODS}" = "true" ]; then
  mapfile -t traefik_nodes < <(
    kubectl get pods -n "${TRAEFIK_NAMESPACE}" -l "${TRAEFIK_POD_SELECTOR}" \
      --field-selector=status.phase=Running \
      -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u
  )
else
  traefik_nodes=("${all_nodes[@]}")
fi

http_backend_servers=""
https_backend_servers=""
index=1
for node in "${all_nodes[@]}"; do
  [ -n "${node}" ] || continue

  if [ "${DISCOVER_TRAEFIK_PODS}" = "true" ]; then
    include_node=false
    for traefik_node in "${traefik_nodes[@]}"; do
      if [ "${node}" = "${traefik_node}" ]; then
        include_node=true
        break
      fi
    done
    [ "${include_node}" = "true" ] || continue
  fi

  node_ip="$(kubectl get node "${node}" -o jsonpath="{.status.addresses[?(@.type=='${KUBE_NODE_ADDRESS_TYPE}')].address}")"
  [ -n "${node_ip}" ] || continue

  http_backend_servers+="    server worker${index} ${node_ip}:${TRAEFIK_HTTP_NODEPORT} check"$'\n'
  https_backend_servers+="    server worker${index} ${node_ip}:${TRAEFIK_HTTPS_NODEPORT} check"$'\n'
  index=$((index + 1))
done

if [ -z "${http_backend_servers}" ]; then
  echo "No Kubernetes nodes discovered for HAProxy backend" >&2
  exit 1
fi

export \
  ALB_DOMAIN \
  HAPROXY_HTTP_BACKEND_SERVERS="${http_backend_servers%$'\n'}" \
  HAPROXY_HTTPS_BACKEND_SERVERS="${https_backend_servers%$'\n'}"
envsubst '${ALB_DOMAIN} ${HAPROXY_HTTP_BACKEND_SERVERS} ${HAPROXY_HTTPS_BACKEND_SERVERS}' \
  < "${SCRIPT_DIR}/haproxy.cfg.tpl" \
  > "${SCRIPT_DIR}/${HAPROXY_CONFIG}"

echo "Wrote ${SCRIPT_DIR}/${HAPROXY_CONFIG}"
printf '%s\n' "${http_backend_servers%$'\n'}"
printf '%s\n' "${https_backend_servers%$'\n'}"
