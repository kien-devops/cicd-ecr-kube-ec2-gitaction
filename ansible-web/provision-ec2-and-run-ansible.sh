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

if [[ -f "${ALB_RELOAD_SCRIPT}" ]] && command -v kubectl >/dev/null 2>&1 && command -v docker >/dev/null 2>&1; then
  echo "==> Reloading HAProxy backend list"
  bash "${ALB_RELOAD_SCRIPT}"
else
  echo "==> Skipping HAProxy reload"
  echo "Run manually if HAProxy is on another server: bash k8s-traefik-lb-demo/alb/reload-haproxy.sh"
fi

echo "==> Done"
echo "Check node status on the control plane with: kubectl get nodes -o wide"
