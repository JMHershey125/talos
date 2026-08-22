#!/bin/bash
set -euo pipefail

CLUSTER_NAME="talos-cluster"
CLUSTER_ENDPOINT="https://10.74.5.11:6443"
PATCH_FILE="talos/cluster-patch.yaml"
OUTPUT_DIR="talos"

if [ ! -f "$PATCH_FILE" ]; then
    echo "Error: Could not find cluster patch at $PATCH_FILE" >&2
    exit 1
fi

echo "=== Step 1: Generating base Talos configurations using $PATCH_FILE ==="
talosctl gen config "$CLUSTER_NAME" "$CLUSTER_ENDPOINT" \
  --config-patch-control-plane "@$PATCH_FILE" \
  --force

# Move generated files into the talos directory
mv controlplane.yaml "$OUTPUT_DIR/controlplane-template.yaml"
if [ -f worker.yaml ]; then mv worker.yaml "$OUTPUT_DIR/"; fi
mv talosconfig "$OUTPUT_DIR/talosconfig"

echo "=== Step 2: Creating node-specific configuration files in $OUTPUT_DIR/ ==="
NODES=("talos01:10.74.5.11" "talos02:10.74.5.12" "talos03:10.74.5.13")

for entry in "${NODES[@]}"; do
    node="${entry%%:*}"
    ip="${entry##*:}"
    output_file="$OUTPUT_DIR/${node}.yaml"
    template_file="$OUTPUT_DIR/controlplane-template.yaml"
    
    echo "Generating configuration for $node ($ip)..."
    cp "$template_file" "$output_file"
    
    # Create a temporary strategic merge patch for this node's network identity
    node_patch=$(mktemp)
    cat << EOF > "$node_patch"
machine:
  network:
    hostname: "$node"
    interfaces:
      - interface: eth0
        dhcp: false
        addresses:
          - "$ip/24"
EOF

    # Apply the strategic merge patch using talosctl machineconfig patch
    talosctl machineconfig patch "$output_file" --patch "@$node_patch" --output "$output_file"
    rm -f "$node_patch"
done

# Clean up temporary template
rm -f "$OUTPUT_DIR/controlplane-template.yaml"

echo "=== Step 3: Updating talosconfig with all cluster nodes and endpoints ==="
TALOSCONFIG="$OUTPUT_DIR/talosconfig"
talosctl config --talosconfig "$TALOSCONFIG" endpoint 10.74.5.11 10.74.5.12 10.74.5.13
talosctl config --talosconfig "$TALOSCONFIG" node 10.74.5.11 10.74.5.12 10.74.5.13

echo "=== Bootstrap generation complete! ==="
ls -la "$OUTPUT_DIR/talos01.yaml" "$OUTPUT_DIR/talos02.yaml" "$OUTPUT_DIR/talos03.yaml" "$OUTPUT_DIR/talosconfig"
echo "BACKUP"
cp -r $OUTPUT_DIR/* /Users/jmhershey125/Documents/kube/
cat << 'EOF' >> ~/.zshrc
ls -la /Users/jmhershey125/Documents/kube/
# Talos Configuration Defaults
export TALOSCONFIG="/Users/jmhershey125/git/talos/talos/talosconfig"
EOF
