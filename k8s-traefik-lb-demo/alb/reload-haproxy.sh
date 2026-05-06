#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/discover-traefik-nodes.sh"

if docker ps --format '{{.Names}}' | grep -qx 'haproxy-alb'; then
  docker restart haproxy-alb >/dev/null
  docker logs --tail 50 haproxy-alb
else
  echo "haproxy-alb is not running. Start it with: docker compose up -d"
fi
