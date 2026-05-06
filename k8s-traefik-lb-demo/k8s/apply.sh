#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GATEWAY_API_CRD_URL="https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml"
TRAEFIK_CRD_URL="https://raw.githubusercontent.com/traefik/traefik/v3.0/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml"

echo "Checking required CRDs..."
kubectl get crd | grep -E 'gatewayclasses|gateways|httproutes|middlewares' || true

if ! kubectl get crd gatewayclasses.gateway.networking.k8s.io gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io >/dev/null 2>&1; then
  echo "Installing Gateway API CRDs..."
  kubectl apply -f "${GATEWAY_API_CRD_URL}"
fi

if ! kubectl get crd middlewares.traefik.io >/dev/null 2>&1; then
  echo "Installing Traefik CRDs..."
  kubectl apply -f "${TRAEFIK_CRD_URL}"
fi

echo "Waiting for CRDs to be ready..."
kubectl wait --for=condition=Established crd/gatewayclasses.gateway.networking.k8s.io --timeout=120s
kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=120s
kubectl wait --for=condition=Established crd/httproutes.gateway.networking.k8s.io --timeout=120s
kubectl wait --for=condition=Established crd/middlewares.traefik.io --timeout=120s

echo "Creating ECR image pull secret..."
bash "${SCRIPT_DIR}/create-ecr-secret.sh"

echo "Applying Traefik and application manifests..."
kubectl apply -f "${SCRIPT_DIR}"

echo "Checking deployed Gateway resources..."
kubectl get gatewayclass
kubectl get gateway -A
kubectl get httproute -A
kubectl get middleware -A
