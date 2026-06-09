#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Stopping Project 18 demo components..."

# 1) Stop Prometheus container if running
if command -v docker >/dev/null 2>&1; then
  if [ "$(docker ps -q -f name=edge-prometheus)" != "" ]; then
    echo "Stopping and removing edge-prometheus container"
    docker rm -f edge-prometheus || true
  else
    echo "Prometheus container not running"
  fi
else
  echo "Docker not found; skipping Prometheus stop"
fi

# 2) Stop Nomad job if Nomad is available
if command -v nomad >/dev/null 2>&1; then
  echo "Stopping Nomad job: store-app (if exists)"
  nomad job stop -purge store-app || true
else
  echo "Nomad not found; skipping Nomad job stop"
fi

# 3) Remove ArgoCD (optional) - only if kubectl present
if command -v kubectl >/dev/null 2>&1; then
  echo "Removing ArgoCD namespace (if exists)"
  kubectl delete namespace argocd --ignore-not-found || true
else
  echo "kubectl not found; skipping ArgoCD removal"
fi

# 4) Bring down WireGuard interface if available
if command -v wg-quick >/dev/null 2>&1; then
  echo "Bringing down wg0 interface (if exists)"
  sudo wg-quick down wg0 || true
else
  echo "wg-quick not found; skipping WireGuard down"
fi

echo "Stop complete."
