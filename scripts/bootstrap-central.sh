#!/usr/bin/env bash
set -euo pipefail

# Bootstrap central WireGuard peer and ArgoCD (minimal)

WG_DIR=${1:-/etc/wireguard}
mkdir -p "$WG_DIR"
umask 077
if [ ! -f "$WG_DIR/privatekey" ]; then
  wg genkey | tee "$WG_DIR/privatekey" | wg pubkey > "$WG_DIR/publickey"
  echo "Generated central WireGuard keys"
fi

cat > "$WG_DIR/wg0.conf" <<EOF
[Interface]
Address = 10.10.0.1/16
PrivateKey = $(cat $WG_DIR/privatekey)
ListenPort = 51820

EOF

echo "WireGuard config written to $WG_DIR/wg0.conf"

# Optionally bootstrap ArgoCD in the current kubecontext
if command -v kubectl >/dev/null 2>&1; then
  echo "Bootstrapping ArgoCD in 'argocd' namespace (requires cluster-admin)"
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  echo "ArgoCD bootstrap applied"
else
  echo "kubectl not found; skipping ArgoCD bootstrap"
fi

echo "Central bootstrap complete. Review $WG_DIR/wg0.conf and share public key with edge nodes."
