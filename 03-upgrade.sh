#!/usr/bin/env bash
set -e

# Define nodes as pairs of IP and Kubernetes node name (or we can auto-discover the K8s node name)
NODES=("10.74.5.11" "10.74.5.12" "10.74.5.13")
TALOS_IMAGE="factory.talos.dev/installer/d30235af7822d8ab9218631278e8cf545cdccb30650607f2211e4f670489587f:v1.13.9"
TALOS_CONFIG="./talos/talosconfig"

echo "=== Step 1: Performing rolling upgrade on Talos nodes one-by-one ==="

for node_ip in "${NODES[@]}"; do
    echo "--------------------------------------------------"
    echo "Processing node: $node_ip"
    
    # Auto-detect Kubernetes node name from the IP address
    k8s_node=$(kubectl get nodes -o wide | grep "$node_ip" | awk '{print $1}')
    
    if [ -n "$k8s_node" ]; then
        echo "-> Draining Kubernetes node: $k8s_node"
        # --ignore-daemonsets is required for Longhorn/CSI pods, --delete-emptydir-data clears local scratch
        kubectl drain "$k8s_node" --ignore-daemonsets --delete-emptydir-data --timeout=180s || {
            echo "Warning: Drain timed out or encountered an issue on $k8s_node, proceeding with caution..."
        }
    else
        echo "-> Warning: Could not find Kubernetes node matching IP $node_ip. Skipping drain."
    fi

    echo "-> Upgrading Talos on node $node_ip..."
    talosctl upgrade --nodes "$node_ip" --image "$TALOS_IMAGE" --talosconfig "$TALOS_CONFIG"

    echo "-> Waiting for node $node_ip to report healthy..."
    talosctl health --nodes "$node_ip" --talosconfig "$TALOS_CONFIG" --wait-timeout=10m

    if [ -n "$k8s_node" ]; then
        echo "-> Uncordoning Kubernetes node: $k8s_node"
        kubectl uncordon "$k8s_node"
    fi

    echo "-> Completed upgrade cycle for $node_ip. Waiting 10s for cluster stabilization..."
    sleep 10
done

echo "--------------------------------------------------"
echo "=== Step 2: Applying GitOps Manifests (ArgoCD) ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --force-conflicts --server-side

echo "Waiting for ArgoCD CRDs/Deployments to stabilize..."
sleep 15
kubectl apply -f /Users/jmhershey125/Documents/kube/sealed-secrets-key.yaml
echo "PASSWORD FOR ARGO ADMIN: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
kubectl apply -f gitops/root.yaml -n argocd
kubectl apply -f gitops/bootstrap.yaml -n argocd
