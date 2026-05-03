#!/usr/bin/env bash
set -euo pipefail

: "${ECR_REGISTRY:?ECR_REGISTRY is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
K8S_DIR="${REPO_ROOT}/k8s-traefik-lb-demo/k8s"

envsubst '${ECR_REGISTRY} ${IMAGE_TAG}' < "${K8S_DIR}/05-fe-deployment.yaml"
printf '\n---\n'
envsubst '${ECR_REGISTRY} ${IMAGE_TAG}' < "${K8S_DIR}/07-be-deployment.yaml"
