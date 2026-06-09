#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

echo "Start complete. Monitor components (kubectl, docker, nomad) as appropriate."
echo "Make the script executable: chmod +x start.sh stop.sh"
