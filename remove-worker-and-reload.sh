#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${ROOT_DIR}/terraform"
ANSIBLE_DIR="${ROOT_DIR}/ansible-web"
ENV_FILE="${ANSIBLE_DIR}/.env"
ALB_RELOAD_SCRIPT="${ROOT_DIR}/k8s-traefik-lb-demo/alb/reload-haproxy.sh"

load_env() {
  if [[ -f "${ENV_FILE}" ]]; then
    while IFS='=' read -r key value; do
      key="${key#"${key%%[![:space:]]*}"}"
      key="${key%"${key##*[![:space:]]}"}"

      [[ -n "${key}" && "${key}" != \#* ]] || continue
      [[ "${key}" == "KUBECONFIG" || "${key}" == ALB_* || "${key}" == CONTROL_PLANE_* ]] || continue

      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"
      value="${value%\"}"
      value="${value#\"}"
      export "${key}=${value}"
    done < "${ENV_FILE}"
  fi
}

latest_tf_node() {
  grep -oE '^[[:space:]]*node[0-9]+[[:space:]]*=' "${TERRAFORM_DIR}/terraform.tfvars" \
    | grep -oE 'node[0-9]+' \
    | sed 's/node//' \
    | sort -n \
    | tail -1 \
    | awk '{print "node"$1}'
}

tf_private_ip() {
  local node_name="$1"
  cd "${TERRAFORM_DIR}"
  terraform output -json private_ips | python3 -c '
import json, sys
node = sys.argv[1]
data = json.load(sys.stdin)
print(data.get(node, ""))
' "${node_name}"
}

k8s_node_from_ip() {
  local private_ip="$1"
  kubectl get nodes -o json | python3 -c '
import json, sys
ip = sys.argv[1]
data = json.load(sys.stdin)
for item in data.get("items", []):
    name = item["metadata"]["name"]
    for addr in item["status"].get("addresses", []):
        if addr.get("type") == "InternalIP" and addr.get("address") == ip:
            print(name)
            sys.exit(0)
sys.exit(1)
' "${private_ip}"
}

load_env

if [[ -n "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG
fi

if [[ ! -f "${TERRAFORM_DIR}/terraform.tfvars" ]]; then
  echo "Missing ${TERRAFORM_DIR}/terraform.tfvars"
  exit 1
fi

TF_NODE_NAME="${1:-}"

if [[ -z "${TF_NODE_NAME}" ]]; then
  TF_NODE_NAME="$(latest_tf_node || true)"
fi

if [[ -z "${TF_NODE_NAME}" ]]; then
  echo "No Terraform worker nodes left to remove."
  exit 0
fi

echo "==> Selected Terraform node for scale-in: ${TF_NODE_NAME}"

PRIVATE_IP="$(tf_private_ip "${TF_NODE_NAME}" || true)"

if [[ -z "${PRIVATE_IP}" ]]; then
  echo "Could not find private IP for ${TF_NODE_NAME} from terraform output."
  echo "Will remove from Terraform only, then reload HAProxy."
else
  echo "==> Private IP: ${PRIVATE_IP}"

  K8S_NODE_NAME="$(k8s_node_from_ip "${PRIVATE_IP}" || true)"

  if [[ -n "${K8S_NODE_NAME}" ]]; then
    echo "==> Kubernetes node: ${K8S_NODE_NAME}"

    echo "==> Draining Kubernetes node"
    kubectl drain "${K8S_NODE_NAME}" \
      --ignore-daemonsets \
      --delete-emptydir-data \
      --force \
      --timeout=180s || true

    echo "==> Deleting Kubernetes node"
    kubectl delete node "${K8S_NODE_NAME}" --ignore-not-found
  else
    echo "==> No Kubernetes node found for IP ${PRIVATE_IP}, skipping kubectl drain/delete"
  fi
fi

echo "==> Removing EC2 worker from Terraform/IaC"
cd "${TERRAFORM_DIR}"
bash remove-node.sh "${TF_NODE_NAME}"

echo "==> Reloading HAProxy backend list"
bash "${ALB_RELOAD_SCRIPT}"

echo "==> Current Kubernetes nodes"
kubectl get nodes -o wide || true

echo "==> Current HAProxy backend servers"
grep '^[[:space:]]*server worker' "${ROOT_DIR}/k8s-traefik-lb-demo/alb/haproxy.cfg" || true

echo "==> Scale-in done"
EOF