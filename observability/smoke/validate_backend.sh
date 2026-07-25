#!/usr/bin/env bash
set -euo pipefail

BACKEND="${OBSERVABILITY_BACKEND:-oss}"

echo "Running smoke validation for backend: ${BACKEND}"
python3 observability/smoke/smoke_test.py

if [[ "${BACKEND}" == "oss" ]]; then
  echo "Checking Prometheus target status..."
  curl -fsS "http://localhost:9090/api/v1/targets" >/dev/null

  echo "Checking Tempo readiness endpoint..."
  curl -fsS "http://localhost:3200/ready" >/dev/null

  echo "OSS smoke validation checks passed (collector + Prometheus + Tempo reachable)."
else
  echo "For ${BACKEND}, validate collector export success in collector logs:"
  echo "docker compose -f observability/docker/docker-compose.yaml logs otel-collector"
fi
