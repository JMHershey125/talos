#!/bin/bash
set -euo pipefail

OUTPUT_DIR="talos"

echo "=== Talos Fresh Cluster Deployment Tool ==="
echo "Please enter the temporary DHCP IP address currently assigned to each fresh node:"
echo ""

read -p "Enter DHCP IP for talos01 (e.g., 10.74.5.X): " dhcp1
read -p "Enter DHCP IP for talos02 (e.g., 10.74.5.X): " dhcp2
read -p "Enter DHCP IP for talos03 (e.g., 10.74.5.X): " dhcp3

echo ""
echo "=== Step 1: Applying configurations and rebooting nodes ==="

echo "Applying talos01.yaml to $dhcp1 (with reboot)..."
talosctl apply-config --insecure --nodes "$dhcp1" --file "$OUTPUT_DIR/talos01.yaml" --mode reboot

echo "Applying talos02.yaml to $dhcp2 (with reboot)..."
talosctl apply-config --insecure --nodes "$dhcp2" --file "$OUTPUT_DIR/talos02.yaml" --mode reboot

echo "Applying talos03.yaml to $dhcp3 (with reboot)..."
talosctl apply-config --insecure --nodes "$dhcp3" --file "$OUTPUT_DIR/talos03.yaml" --mode reboot

echo ""
echo "=== Step 2: Waiting for nodes to come up on static IPs (10.74.5.11-13)... ==="
sleep 60


echo "Bootstrapping Etcd on talos01 (10.74.5.11)..."
talosctl bootstrap --nodes 10.74.5.11 --talosconfig "$OUTPUT_DIR/talosconfig"

echo ""
echo "=== Step 3: Retrieving Kubeconfig ==="
mkdir -p ~/.kube
talosctl kubeconfig -f --nodes 10.74.5.11 --talosconfig "$OUTPUT_DIR/talosconfig" ~/.kube/config

echo ""
echo "=== Deployment Complete! ==="
