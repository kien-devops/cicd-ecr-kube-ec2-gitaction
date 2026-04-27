#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

TFVARS="terraform.tfvars"
node_name="${1:-}"

if [[ ! -f "$TFVARS" ]]; then
  echo "Missing $TFVARS"
  exit 1
fi

if [[ -z "$node_name" ]]; then
  max_node_number="$(
    grep -oE '^[[:space:]]*node[0-9]+[[:space:]]*=' "$TFVARS" \
      | grep -oE 'node[0-9]+' \
      | sed 's/node//' \
      | sort -n \
      | tail -1 || true
  )"

  if [[ -z "$max_node_number" ]]; then
    echo "No node found in $TFVARS"
    exit 1
  fi

  node_name="node${max_node_number}"
fi

if ! grep -Eq "^[[:space:]]*${node_name}[[:space:]]*=" "$TFVARS"; then
  echo "$node_name does not exist in $TFVARS"
  exit 1
fi

tmp_file="$(mktemp)"

awk -v node_name="$node_name" '
  BEGIN {
    removing = 0
    remove_depth = 0
    removed = 0
  }

  {
    if (removing == 0 && $0 ~ "^[[:space:]]*" node_name "[[:space:]]*=[[:space:]]*\\{") {
      open_line = $0
      close_line = $0
      open_count = gsub(/\{/, "", open_line)
      close_count = gsub(/\}/, "", close_line)
      remove_depth = open_count - close_count
      removing = 1
      removed = 1

      if (remove_depth <= 0) {
        removing = 0
      }

      next
    }

    if (removing == 1) {
      open_line = $0
      close_line = $0
      open_count = gsub(/\{/, "", open_line)
      close_count = gsub(/\}/, "", close_line)
      remove_depth += open_count - close_count

      if (remove_depth <= 0) {
        removing = 0
      }

      next
    }

    print
  }

  END {
    if (removed == 0) {
      exit 2
    }
  }
' "$TFVARS" > "$tmp_file"

mv "$tmp_file" "$TFVARS"

terraform fmt
terraform init
terraform apply -auto-approve
