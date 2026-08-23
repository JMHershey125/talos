echo "Upgrading to load extensions"
talosctl upgrade --nodes 10.74.5.11,10.74.5.12,10.74.5.13 \
  --image factory.talos.dev/installer/d30235af7822d8ab9218631278e8cf545cdccb30650607f2211e4f670489587f:v1.13.7 \
  --talosconfig ./talos/talosconfig
echo "Starting Kube config"
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
sleep 15
echo "PASSWORD FOR ARGO ADMIN: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
kubectl apply -f gitops/root.yaml -n argocd
