#!/bin/bash
set -euo pipefail

# ==========================================
# ENVIRONMENT & HARDWARE CONFIGURATION
# ==========================================
CLUSTER_NAME="talos-cluster"
CLUSTER_ENDPOINT="https://10.74.5.11:6443"
PATCH_FILE="talos/cluster-patch.yaml"
OUTPUT_DIR="talos"

# Hardware / Hypervisor specific settings
INTERFACE="enX0"
OS_DISK="/dev/xvda"
DATA_DISK="/dev/xvdb"

# Network Gateway & DNS Settings (Adjust as needed)
GATEWAY="10.74.5.1"
NAMESERVERS=("10.74.5.1" "1.1.1.1")

if [ ! -f "$PATCH_FILE" ]; then
    echo "Error: Could not find cluster patch at $PATCH_FILE" >&2
    exit 1
fi

echo "=== Step 1: Generating base Talos configurations using $PATCH_FILE ==="
talosctl gen config "$CLUSTER_NAME" "$CLUSTER_ENDPOINT" \
  --config-patch-control-plane "@$PATCH_FILE" \
  --force

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
    
    # Cleanly split multi-document YAML and keep only the first document (the main config)
    python3 -c "
with open('$output_file', 'r') as f:
    content = f.read()
docs = content.split('---')
with open('$output_file', 'w') as f:
    f.write(docs[0].strip() + '\n')
"
    
    # Create a strategic merge patch for hostname, static IP, gateway, DNS, and disks
    node_patch=$(mktemp)
    cat << EOF > "$node_patch"
machine:
  network:
    hostname: "$node"
    nameservers:
      - ${NAMESERVERS[0]}
      - ${NAMESERVERS[1]}
    interfaces:
      - interface: $INTERFACE
        dhcp: false
        addresses:
          - "$ip/24"
        routes:
          - network: 0.0.0.0/0
            gateway: $GATEWAY
  disks:
    - device: $DATA_DISK
      partitions:
        - mountpoint: /var/lib/longhorn
  install:
    disk: $OS_DISK
EOF

    talosctl machineconfig patch "$output_file" --patch "@$node_patch" --output "$output_file"
    rm -f "$node_patch"
done

rm -f "$OUTPUT_DIR/controlplane-template.yaml"

echo "=== Step 3: Updating talosconfig endpoints and nodes ==="
TALOSCONFIG="$OUTPUT_DIR/talosconfig"
talosctl config --talosconfig "$TALOSCONFIG" endpoint 10.74.5.11 10.74.5.12 10.74.5.13
talosctl config --talosconfig "$TALOSCONFIG" node 10.74.5.11 10.74.5.12 10.74.5.13

echo "=== Bootstrap generation complete! ==="
ls -la "$OUTPUT_DIR/talos01.yaml" "$OUTPUT_DIR/talos02.yaml" "$OUTPUT_DIR/talos03.yaml" "$OUTPUT_DIR/talosconfig"

echo "BACKUP"
mkdir -p /Users/jmhershey125/Documents/kube/
cp -r "$OUTPUT_DIR"/* /Users/jmhershey125/Documents/kube/
ls -la /Users/jmhershey125/Documents/kube/

if ! grep -q "TALOSCONFIG" ~/.zshrc; then
    cat << 'EOF' >> ~/.zshrc

# Talos Configuration Defaults
export TALOSCONFIG="/Users/jmhershey125/git/talos/talos/talosconfig"
EOF
    echo "Added TALOSCONFIG export to ~/.zshrc"
else
    echo "TALOSCONFIG export already exists in ~/.zshrc"
fi
