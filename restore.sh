cp -r /Users/jmhershey125/Documents/kube/* /Users/jmhershey125/git/talos/
cat << 'EOF' >> ~/.zshrc

# Talos Configuration Defaults
export TALOSCONFIG="/Users/jmhershey125/git/talos/talosconfig"
export TALOS_ENDPOINTS="10.74.5.87 10.74.5.69 10.74.5.216"
export TALOS_NODES="10.74.5.87"
EOF
