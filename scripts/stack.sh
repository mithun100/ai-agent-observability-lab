#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/observability/docker/docker-compose.yaml"
ENV_FILE="${ROOT_DIR}/.env"

ACTION="${1:-up}"
shift || true

check_http() {
  local name="$1"
  local url="$2"
  local tries="${3:-12}"
  local sleep_s="${4:-2}"
  local code="000"
  local i=1

  while [[ "${i}" -le "${tries}" ]]; do
    code="$(curl -s -o /dev/null -w "%{http_code}" "${url}" || true)"
    if [[ "${code}" == "200" ]]; then
      echo "[OK] ${name}: ${url}"
      return 0
    fi
    if [[ "${i}" -lt "${tries}" ]]; then
      sleep "${sleep_s}"
    fi
    i=$((i + 1))
  done

  echo "[FAIL] ${name}: ${url} (HTTP ${code:-000})"
  return 1
}

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Create it from .env.example first."
  exit 1
fi

case "${ACTION}" in
  up)
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d --build "$@"
    ;;
  down)
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" down "$@"
    ;;
  ps)
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps "$@"
    ;;
  logs)
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" logs -f "$@"
    ;;
  restart)
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" down
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d --build "$@"
    ;;
  config)
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" config "$@"
    ;;
  health)
    planner_ok=0
    for _ in {1..12}; do
      planner_code="$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/travel/plan || true)"
      if [[ "${planner_code}" == "200" || "${planner_code}" == "405" ]]; then
        echo "[OK] travel-planner: http://localhost:8080/travel/plan (HTTP ${planner_code})"
        planner_ok=1
        break
      fi
      sleep 2
    done
    if [[ "${planner_ok}" -ne 1 ]]; then
      echo "[FAIL] travel-planner: http://localhost:8080/travel/plan (HTTP ${planner_code:-000})"
      exit 1
    fi
    check_http "prometheus" "http://localhost:9090/-/healthy"
    check_http "tempo" "http://localhost:3200/ready"
    check_http "loki" "http://localhost:3100/ready"
    ;;
  test)
    status="$(curl -sS -o /tmp/travel-plan-response.json -w "%{http_code}" \
      -X POST http://localhost:8080/travel/plan \
      -H "Content-Type: application/json" \
      -d '{"source":"Bengaluru","destination":"Tokyo","date":"2026-12-10"}')"
    if [[ "${status}" != "200" ]]; then
      echo "[FAIL] /travel/plan returned HTTP ${status}"
      cat /tmp/travel-plan-response.json
      exit 1
    fi

    if grep -qE 'itinerary|travel_plan|destination|flight' /tmp/travel-plan-response.json; then
      echo "[OK] /travel/plan returned HTTP 200 with itinerary-like response"
      cat /tmp/travel-plan-response.json
    else
      echo "[WARN] /travel/plan returned HTTP 200 but response shape was unexpected"
      cat /tmp/travel-plan-response.json
    fi
    ;;
  *)
    echo "Usage: scripts/stack.sh {up|down|ps|logs|restart|config|health|test} [extra docker compose args]"
    exit 2
    ;;
esac
