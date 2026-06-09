#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMETHEUS_HOST_PORT=""

print_access_info() {
  echo
  echo "Access summary"
  echo "--------------"

  if [ -n "$PROMETHEUS_HOST_PORT" ]; then
    echo "Prometheus UI: http://127.0.0.1:${PROMETHEUS_HOST_PORT}"
    echo "Prometheus has no default username/password in this setup"
  fi

  if command -v kubectl >/dev/null 2>&1 && kubectl get namespace argocd >/dev/null 2>&1; then
    echo "ArgoCD UI: kubectl -n argocd port-forward svc/argocd-server 8080:443"
    echo "ArgoCD URL: https://127.0.0.1:8080"
    echo "ArgoCD username: admin"

    if kubectl -n argocd get secret argocd-initial-admin-secret >/dev/null 2>&1; then
      ARGOCD_ADMIN_PASSWORD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode 2>/dev/null || true)"
      if [ -n "$ARGOCD_ADMIN_PASSWORD" ]; then
        echo "ArgoCD password: $ARGOCD_ADMIN_PASSWORD"
      else
        echo "ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode"
      fi
    else
      echo "ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode"
    fi
  fi

  if command -v kubectl >/dev/null 2>&1 && kubectl get namespace store-app >/dev/null 2>&1; then
    echo "Store app UI: kubectl -n store-app port-forward svc/store-app 8081:80"
    echo "Store app URL: http://127.0.0.1:8081"
  fi
}

echo "Starting Project 18 demo components..."

# 1) Ensure central WireGuard keys and optionally install ArgoCD
if command -v bash >/dev/null 2>&1; then
  echo "Running central bootstrap (WireGuard keys + optional ArgoCD install)"
  "$ROOT_DIR/scripts/bootstrap-central.sh" "$ROOT_DIR/.wg" || true
fi

# 2) Start Prometheus (container) using the federation config
if command -v docker >/dev/null 2>&1; then
  if [ -n "$(docker ps -q -f name=^/edge-prometheus$)" ]; then
    echo "Prometheus container already running"
    PROMETHEUS_HOST_PORT="$(docker port edge-prometheus 9090/tcp 2>/dev/null | awk -F: 'NR==1 {print $2}')"
  else
    if [ -n "$(docker ps -aq -f name=^/edge-prometheus$)" ]; then
      echo "Removing stale edge-prometheus container"
      docker rm -f edge-prometheus >/dev/null 2>&1 || true
    fi

    echo "Starting Prometheus container (edge-prometheus)"
    PROMETHEUS_PORT=${PROMETHEUS_PORT:-9090}
    while command -v ss >/dev/null 2>&1 && ss -ltn | awk -v port=":$PROMETHEUS_PORT" 'NR > 1 && $4 ~ port "$" { found = 1 } END { exit found ? 0 : 1 }'; do
      echo "Port $PROMETHEUS_PORT is already in use; trying $((PROMETHEUS_PORT + 1))"
      PROMETHEUS_PORT=$((PROMETHEUS_PORT + 1))
    done
    if docker run -d --name edge-prometheus -p "$PROMETHEUS_PORT:9090" \
      -v "$ROOT_DIR/monitoring/prometheus-federation.yaml":/etc/prometheus/prometheus.yml \
      -v "$ROOT_DIR/monitoring":/etc/prometheus/rules \
      prom/prometheus:latest --config.file=/etc/prometheus/prometheus.yml; then
      PROMETHEUS_HOST_PORT="$PROMETHEUS_PORT"
      echo "Prometheus container exposed on host port $PROMETHEUS_PORT"
    else
      echo "Failed to start Prometheus container"
    fi
  fi
else
  echo "Docker not found; skipping Prometheus start"
fi

# 3) Submit Nomad job if Nomad is available
if command -v nomad >/dev/null 2>&1; then
  echo "Running Nomad job: store-app"
  nomad job run "$ROOT_DIR/nomad/jobs/store_app.nomad" || true
else
  echo "Nomad not found; skipping Nomad job submission"
fi

print_access_info

echo "Start complete. Monitor components (kubectl, docker, nomad) as appropriate."
echo "Make the script executable: chmod +x start.sh stop.sh"
