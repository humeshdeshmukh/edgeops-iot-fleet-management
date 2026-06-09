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
  if [ "$(docker ps -q -f name=edge-prometheus)" = "" ]; then
    echo "Starting Prometheus container (edge-prometheus)"
    docker run -d --name edge-prometheus -p 9090:9090 \
      -v "$ROOT_DIR/monitoring/prometheus-federation.yaml":/etc/prometheus/prometheus.yml \
      -v "$ROOT_DIR/monitoring":/etc/prometheus/rules \
      prom/prometheus:latest --config.file=/etc/prometheus/prometheus.yml || true
  else
    echo "Prometheus container already running"
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
