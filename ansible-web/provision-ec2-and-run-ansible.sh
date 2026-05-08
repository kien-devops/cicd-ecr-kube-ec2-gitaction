
#!/usr/bin/env bash
set -euo pipefail

ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${ANSIBLE_DIR}/.." && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/terraform"

TFVARS_FILE="${TERRAFORM_DIR}/terraform.tfvars"
ADD_NODE_SCRIPT="${TERRAFORM_DIR}/add-node.sh"
ENV_FILE="${ANSIBLE_DIR}/.env"
INVENTORY_FILE="${ANSIBLE_DIR}/hosts.ini"
PLAYBOOK_FILE="${ANSIBLE_DIR}/join_k8s.yml"
KEY_FILE="${ANSIBLE_DIR}/kien.pem"

ALB_RELOAD_SCRIPT="${ROOT_DIR}/k8s-traefik-lb-demo/alb/reload-haproxy.sh"
HAPROXY_CONFIG_HOST="${ROOT_DIR}/k8s-traefik-lb-demo/alb/haproxy.cfg"
HAPROXY_CONTAINER_NAME="${HAPROXY_CONTAINER_NAME:-haproxy-alb}"
HAPROXY_CONTAINER_CONFIG="/usr/local/etc/haproxy/haproxy.cfg"

load_alb_env() {
  while IFS='=' read -r key value; do
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"

    [[ -n "${key}" && "${key}" != \#* ]] || continue
    [[ "${key}" == ALB_* || "${key}" == "KUBECONFIG" || "${key}" == CONTROL_PLANE_* ]] || continue

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value="${value%\"}"
    value="${value#\"}"

    export "${key}=${value}"
  done < "${ENV_FILE}"
}

show_k8s_nodes() {
  echo "==> Current Kubernetes nodes"
  kubectl get nodes -o wide
}

wait_for_traefik_ready() {
  echo "==> Waiting for Traefik DaemonSet to roll out"
  kubectl rollout status daemonset/traefik -n traefik --timeout=300s

  echo "==> Traefik pods"
  kubectl get pods -n traefik -o wide
}

detect_newest_tf_node_ip() {
  cd "${TERRAFORM_DIR}"

  terraform output -json private_ips | python3 -c '
import json
import sys

data = json.load(sys.stdin)

if not data:
    sys.exit(1)

def node_num(name):
    try:
        return int(name.replace("node", ""))
    except Exception:
        return -1

latest = sorted(data.keys(), key=node_num)[-1]
print(data[latest])
'
}

find_k8s_node_by_ip() {
  local node_ip="$1"

  kubectl get nodes -o json | python3 -c '
import json
import sys

target_ip = sys.argv[1]
data = json.load(sys.stdin)

for item in data.get("items", []):
    node_name = item["metadata"]["name"]
    for addr in item.get("status", {}).get("addresses", []):
        if addr.get("type") == "InternalIP" and addr.get("address") == target_ip:
            print(node_name)
            sys.exit(0)

sys.exit(1)
' "${node_ip}"
}

find_ready_traefik_pod_on_node() {
  local node_name="$1"

  kubectl get pods -n traefik -o json | python3 -c '
import json
import sys

target_node = sys.argv[1]
data = json.load(sys.stdin)

for pod in data.get("items", []):
    if pod.get("spec", {}).get("nodeName") != target_node:
        continue

    phase = pod.get("status", {}).get("phase")
    statuses = pod.get("status", {}).get("containerStatuses", [])

    ready = any(c.get("ready") for c in statuses)

    if phase == "Running" and ready:
        print(pod["metadata"]["name"])
        sys.exit(0)

sys.exit(1)
' "${node_name}"
}

wait_for_new_node_and_traefik_pod() {
  echo "==> Detecting newest Terraform worker private IP"

  NEW_NODE_IP="$(detect_newest_tf_node_ip || true)"

  if [[ -z "${NEW_NODE_IP}" ]]; then
    echo "Could not detect newest node private IP from Terraform output"
    exit 1
  fi

  echo "==> New node private IP: ${NEW_NODE_IP}"

  echo "==> Waiting for Kubernetes node with IP ${NEW_NODE_IP} to appear"

  NEW_K8S_NODE=""

  for _ in {1..60}; do
    NEW_K8S_NODE="$(find_k8s_node_by_ip "${NEW_NODE_IP}" || true)"

    if [[ -n "${NEW_K8S_NODE}" ]]; then
      echo "==> New Kubernetes node: ${NEW_K8S_NODE}"
      break
    fi

    sleep 5
  done

  if [[ -z "${NEW_K8S_NODE}" ]]; then
    echo "New Kubernetes node with IP ${NEW_NODE_IP} was not found"
    kubectl get nodes -o wide || true
    exit 1
  fi

  echo "==> Waiting for ${NEW_K8S_NODE} to become Ready"
  kubectl wait --for=condition=Ready "node/${NEW_K8S_NODE}" --timeout=300s

  echo "==> Waiting for Traefik pod on ${NEW_K8S_NODE}"

  TRAEFIK_POD_ON_NEW_NODE=""

  for _ in {1..60}; do
    TRAEFIK_POD_ON_NEW_NODE="$(find_ready_traefik_pod_on_node "${NEW_K8S_NODE}" || true)"

    if [[ -n "${TRAEFIK_POD_ON_NEW_NODE}" ]]; then
      echo "==> Traefik pod ready on new node: ${TRAEFIK_POD_ON_NEW_NODE}"
      break
    fi

    echo "Waiting for Traefik pod on ${NEW_K8S_NODE}..."
    sleep 5
  done

  if [[ -z "${TRAEFIK_POD_ON_NEW_NODE}" ]]; then
    echo "Traefik pod did not become ready on ${NEW_K8S_NODE}"
    kubectl get pods -n traefik -o wide || true
    exit 1
  fi

  echo "==> New node and Traefik are ready"
  kubectl get nodes -o wide
  kubectl get pods -n traefik -o wide
}

reload_haproxy_backend() {
  echo "==> Reloading HAProxy backend list"

  if [[ -n "${ALB_RELOAD_TARGET}" ]]; then
    echo "==> Reloading HAProxy on remote target ${ALB_RELOAD_TARGET}"
    ssh \
      -p "${ALB_RELOAD_SSH_PORT}" \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=accept-new \
      -i "${ALB_RELOAD_SSH_KEY}" \
      "${ALB_RELOAD_TARGET}" \
      "${ALB_RELOAD_COMMAND}"
    return
  fi

  if [[ ! -f "${ALB_RELOAD_SCRIPT}" ]]; then
    echo "Missing ${ALB_RELOAD_SCRIPT}"
    exit 1
  fi

  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl not found locally, cannot reload HAProxy safely"
    exit 1
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "docker not found locally, cannot reload local HAProxy"
    exit 1
  fi

  bash "${ALB_RELOAD_SCRIPT}"

  echo "==> Verifying HAProxy backend config on host"
  grep '^[[:space:]]*server worker' "${HAPROXY_CONFIG_HOST}" || true

  echo "==> Verifying HAProxy backend config in container"
  sudo docker exec "${HAPROXY_CONTAINER_NAME}" \
    grep '^[[:space:]]*server worker' "${HAPROXY_CONTAINER_CONFIG}" || true

  echo "==> Recent HAProxy backend logs"
  sudo docker logs --since 2m "${HAPROXY_CONTAINER_NAME}" \
    | grep -E 'traefik_nodes_http|DOWN|UP|Loading success|Reloading' || true
}

if [[ ! -f "${TFVARS_FILE}" ]]; then
  echo "Missing ${TFVARS_FILE}"
  echo "Create it from terraform/terraform.tfvars.example first."
  exit 1
fi

if [[ ! -f "${ADD_NODE_SCRIPT}" ]]; then
  echo "Missing ${ADD_NODE_SCRIPT}"
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}"
  echo "Create it from ansible-web/.env.example and add KUBEADM_JOIN_COMMAND."
  exit 1
fi

if [[ ! -f "${KEY_FILE}" ]]; then
  echo "Missing ${KEY_FILE}"
  echo "Copy your AWS EC2 private key to ansible-web/kien.pem, then run:"
  echo "chmod 400 ansible-web/kien.pem"
  exit 1
fi

load_alb_env

if [[ -n "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG
fi

ALB_RELOAD_TARGET="${ALB_RELOAD_TARGET:-}"
ALB_RELOAD_SSH_KEY="${ALB_RELOAD_SSH_KEY:-${KEY_FILE}}"
ALB_RELOAD_SSH_PORT="${ALB_RELOAD_SSH_PORT:-22}"
ALB_RELOAD_DIR="${ALB_RELOAD_DIR:-${ROOT_DIR}/k8s-traefik-lb-demo/alb}"
ALB_RELOAD_COMMAND="${ALB_RELOAD_COMMAND:-cd ${ALB_RELOAD_DIR} && bash ./reload-haproxy.sh}"

echo "==> Adding one EC2 node with Terraform"
bash "${ADD_NODE_SCRIPT}"

echo "==> Terraform outputs"
cd "${TERRAFORM_DIR}"
terraform output

if [[ ! -f "${INVENTORY_FILE}" ]]; then
  echo "Missing generated inventory: ${INVENTORY_FILE}"
  echo "Check ansible_inventory_path in ${TFVARS_FILE}."
  exit 1
fi

echo "==> Running Ansible"
cd "${ANSIBLE_DIR}"
chmod 400 "${KEY_FILE}" || true
ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK_FILE}"

if command -v kubectl >/dev/null 2>&1; then
  show_k8s_nodes
  wait_for_new_node_and_traefik_pod
  wait_for_traefik_ready
else
  echo "kubectl not found locally, cannot wait for Kubernetes node/Traefik"
  exit 1
fi

reload_haproxy_backend

echo "==> Done"
echo "Check node status with: kubectl get nodes -o wide"
echo "Check HAProxy backend with: sudo docker exec ${HAPROXY_CONTAINER_NAME} grep 'server worker' ${HAPROXY_CONTAINER_CONFIG}"
