#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REGISTRY="${ECR_REGISTRY:-606030503959.dkr.ecr.us-east-1.amazonaws.com}"
NAMESPACE="${NAMESPACE:-hospital}"
SECRET_NAME="${SECRET_NAME:-ecr-secret}"
AWS_CLI="${AWS_CLI:-$(command -v aws || true)}"

if [ -z "${AWS_CLI}" ] && [ -x /usr/local/bin/aws ]; then
  AWS_CLI=/usr/local/bin/aws
fi

if [ -z "${AWS_CLI}" ] && [ -x /usr/bin/aws ]; then
  AWS_CLI=/usr/bin/aws
fi

if [ -z "${AWS_CLI}" ]; then
  echo "aws CLI is not found. Run without sudo, or set AWS_CLI=/path/to/aws." >&2
  exit 1
fi

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl delete secret "${SECRET_NAME}" -n "${NAMESPACE}" --ignore-not-found

ECR_PASSWORD="$("${AWS_CLI}" ecr get-login-password --region "${AWS_REGION}")"

kubectl create secret docker-registry "${SECRET_NAME}" \
  --docker-server="${ECR_REGISTRY}" \
  --docker-username=AWS \
  --docker-password="${ECR_PASSWORD}" \
  -n "${NAMESPACE}"

kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}"
