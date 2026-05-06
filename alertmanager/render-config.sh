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

: "${SCALE_WEBHOOK_URL:=http://scale-webhook:5001/scale-ec2}"

export SCALE_WEBHOOK_URL

envsubst '${SCALE_WEBHOOK_URL}' \
  < "${SCRIPT_DIR}/alertmanager.yml.tpl" \
  > "${SCRIPT_DIR}/alertmanager.yml"

echo "Wrote ${SCRIPT_DIR}/alertmanager.yml"
