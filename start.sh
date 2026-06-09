#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMETHEUS_HOST_PORT=""
ARGOCD_HOST_PORT=""
STORE_APP_HOST_PORT=""
FRONTEND_HOST_PORT=""
RUNTIME_DIR="$ROOT_DIR/.runtime"

mkdir -p "$RUNTIME_DIR"

print_section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

find_free_port() {
  local port="${1:-0}"
  while command -v ss >/dev/null 2>&1 && ss -ltn | awk -v port=":$port" 'NR > 1 && $4 ~ port "$" { found = 1 } END { exit found ? 0 : 1 }'; do
    port=$((port + 1))
  done
  printf '%s\n' "$port"
}

start_port_forward() {
  local namespace="$1"
  local target="$2"
  local desired_port="$3"
  local remote_port="$4"
  local label="$5"
  local result_var="$6"

  if ! command -v kubectl >/dev/null 2>&1; then
    echo "$label: kubectl not found; skipping"
    return 0
  fi

  if ! kubectl -n "$namespace" get "$target" >/dev/null 2>&1; then
    echo "$label: $target not found in namespace $namespace; skipping"
    return 0
  fi

  local local_port
  local_port="$(find_free_port "$desired_port")"
  if [ "$local_port" != "$desired_port" ]; then
    echo "$label: port $desired_port in use; using $local_port"
  fi

  local log_file="$RUNTIME_DIR/${label}.log"
  nohup kubectl -n "$namespace" port-forward "$target" "$local_port:$remote_port" --address 127.0.0.1 >"$log_file" 2>&1 &
  printf -v "$result_var" '%s' "$local_port"
  echo "$label: started on http://127.0.0.1:$local_port"
}

print_access_info() {
  echo
  echo "Access summary"
  echo "--------------"

  if [ -n "$PROMETHEUS_HOST_PORT" ]; then
    echo "Prometheus UI: http://127.0.0.1:${PROMETHEUS_HOST_PORT}"
    echo "Prometheus has no default username/password in this setup"
  fi

  if [ -n "$ARGOCD_HOST_PORT" ]; then
    echo "ArgoCD UI: https://127.0.0.1:${ARGOCD_HOST_PORT}"
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

  if [ -n "$STORE_APP_HOST_PORT" ]; then
    echo "Store app URL: http://127.0.0.1:${STORE_APP_HOST_PORT}"
  fi

  if [ -n "$FRONTEND_HOST_PORT" ]; then
    echo "Frontend URL: http://127.0.0.1:${FRONTEND_HOST_PORT}"
  else
    echo "Frontend URL: http://127.0.0.1:5173"
  fi
  echo "Frontend has no default username/password in this setup"
}

print_section "Project 18 Demo Start"
echo "Starting Project 18 demo components..."

print_section "1. Central Bootstrap"
if command -v bash >/dev/null 2>&1; then
  echo "Running central bootstrap (WireGuard keys + optional ArgoCD install)"
  "$ROOT_DIR/scripts/bootstrap-central.sh" "$ROOT_DIR/.wg" || true
fi

print_section "2. Prometheus"
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

print_section "3. ArgoCD"
if command -v kubectl >/dev/null 2>&1 && kubectl get namespace argocd >/dev/null 2>&1; then
  start_port_forward argocd svc/argocd-server 8080 443 "argocd" ARGOCD_HOST_PORT
else
  echo "ArgoCD namespace not available; skipping port-forward"
fi

print_section "4. Store App"
if command -v helm >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1; then
  echo "Deploying store-app Helm chart"
  if helm upgrade --install store-app "$ROOT_DIR/deployments/store-app" --namespace store-app --create-namespace >"$RUNTIME_DIR/store-app-helm.log" 2>&1; then
    echo "store-app Helm release ready"
  else
    echo "store-app Helm release reported an error; continuing"
  fi

  kubectl -n store-app wait --for=condition=available deployment/store-app --timeout=120s >/dev/null 2>&1 || true
  start_port_forward store-app svc/store-app 8081 80 "store-app" STORE_APP_HOST_PORT
else
  echo "helm or kubectl not found; skipping store-app deployment"
fi

print_section "5. Nomad"
if command -v nomad >/dev/null 2>&1; then
  echo "Running Nomad job: store-app"
  nomad job run "$ROOT_DIR/nomad/jobs/store_app.nomad" || true
else
  echo "Nomad not found; skipping Nomad job submission"
fi

print_section "6. Frontend"
if [ -f "$ROOT_DIR/frontend/package.json" ]; then
  if command -v npm >/dev/null 2>&1; then
    if [ ! -d "$ROOT_DIR/frontend/node_modules" ]; then
      echo "Installing frontend dependencies"
      (cd "$ROOT_DIR/frontend" && npm install --no-audit --no-fund)
    fi

    FRONTEND_PORT=${FRONTEND_PORT:-5173}
    FRONTEND_PORT="$(find_free_port "$FRONTEND_PORT")"
    if (cd "$ROOT_DIR/frontend" && nohup npm run dev -- --host 127.0.0.1 --port "$FRONTEND_PORT" > "$RUNTIME_DIR/frontend.log" 2>&1 &); then
      FRONTEND_HOST_PORT="$FRONTEND_PORT"
      echo "Frontend started on http://127.0.0.1:$FRONTEND_PORT"
    else
      echo "Failed to start frontend dev server"
    fi
  else
    echo "npm not found; skipping frontend start"
  fi
fi

print_section "Access Summary"
print_access_info

echo "Start complete. Monitor components (kubectl, docker, nomad) as appropriate."
echo "Make the script executable: chmod +x start.sh stop.sh"
