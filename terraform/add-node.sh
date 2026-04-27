#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

TFVARS="terraform.tfvars"

if [[ ! -f "$TFVARS" ]]; then
  echo "Missing $TFVARS"
  exit 1
fi

max_node_number="$(
  grep -oE '^[[:space:]]*node[0-9]+[[:space:]]*=' "$TFVARS" \
    | grep -oE 'node[0-9]+' \
    | sed 's/node//' \
    | sort -n \
    | tail -1 || true
)"

if [[ -z "$max_node_number" ]]; then
  next_node_number=1
else
  next_node_number=$((max_node_number + 1))
fi

node_name="${1:-node${next_node_number}}"
node_instance_type="${2:-}"

if [[ -z "$node_instance_type" ]]; then
  node_instance_type="$(
    awk -F '"' '/^[[:space:]]*instance_type[[:space:]]*=/ { print $2; exit }' "$TFVARS"
  )"
fi

if [[ -z "$node_instance_type" ]]; then
  echo "Cannot determine instance type. Usage: ./add-node.sh [node_name] [instance_type]"
  exit 1
fi

if grep -Eq "^[[:space:]]*${node_name}[[:space:]]*=" "$TFVARS"; then
  echo "$node_name already exists in $TFVARS"
  exit 1
fi

tmp_file="$(mktemp)"

awk -v node_name="$node_name" -v node_instance_type="$node_instance_type" '
  BEGIN {
    in_nodes = 0
    depth = 0
    inserted = 0
  }

  /^[[:space:]]*nodes[[:space:]]*=[[:space:]]*{[[:space:]]*$/ {
    in_nodes = 1
    depth = 1
    print
    next
  }

  {
    open_line = $0
    close_line = $0
    open_count = gsub(/\{/, "", open_line)
    close_count = gsub(/\}/, "", close_line)

    if (in_nodes && depth - close_count == 0 && inserted == 0) {
      print ""
      print "  " node_name " = {"
      print "    instance_type = \"" node_instance_type "\""
      print "  }"
      inserted = 1
    }

    print

    if (in_nodes) {
      depth += open_count - close_count
      if (depth == 0) {
        in_nodes = 0
      }
    }
  }

  END {
    if (inserted == 0) {
      print ""
      print "nodes = {"
      print "  " node_name " = {"
      print "    instance_type = \"" node_instance_type "\""
      print "  }"
      print "}"
    }
  }
' "$TFVARS" > "$tmp_file"

mv "$tmp_file" "$TFVARS"

terraform fmt
terraform init
terraform apply -auto-approve

