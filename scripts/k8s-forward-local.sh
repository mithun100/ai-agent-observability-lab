#!/usr/bin/env bash
set -euo pipefail

# Local-only helper for Docker Desktop Kubernetes hybrid mode.
# Not intended for managed clusters (EKS/GKE/AKS).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_DIR="/tmp/agent-observability-lab"
mkdir -p "${PID_DIR}"

NAMESPACE="travel-observability"
APP_LOCAL_PORT="18080"
APP_TARGET="svc/travel-planner"
APP_TARGET_PORT="8080"
APP_PID_FILE="${PID_DIR}/pf-app.pid"
APP_LOG_FILE="${PID_DIR}/pf-app.log"

COL_LOCAL_PORT="19464"
COL_TARGET="svc/otel-collector"
COL_TARGET_PORT="9464"
COL_PID_FILE="${PID_DIR}/pf-collector.pid"
COL_LOG_FILE="${PID_DIR}/pf-collector.log"

usage() {
  cat <<'USAGE'
Usage:
  scripts/k8s-forward-local.sh start app
  scripts/k8s-forward-local.sh start collector
  scripts/k8s-forward-local.sh start all
  scripts/k8s-forward-local.sh stop app
  scripts/k8s-forward-local.sh stop collector
  scripts/k8s-forward-local.sh stop all
  scripts/k8s-forward-local.sh status

Notes:
- Local-only workflow for Docker Desktop Kubernetes hybrid mode.
- App forward:       localhost:18080 -> travel-planner:8080
- Collector forward: localhost:19464 -> otel-collector:9464
USAGE
}

is_pid_alive() {
  local pid="$1"
  kill -0 "$pid" >/dev/null 2>&1
}

port_in_use() {
  local port="$1"
  lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
}

kill_kubectl_listener_by_port() {
  local port="$1"
  local pids
  pids="$(lsof -t -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true)"

  if [[ -z "${pids}" ]]; then
    return 0
  fi

  local killed=0
  for pid in ${pids}; do
    local comm
    comm="$(ps -p "${pid}" -o comm= 2>/dev/null | xargs || true)"
    if [[ "${comm}" == "kubectl" ]]; then
      kill "${pid}" >/dev/null 2>&1 || true
      sleep 1
      if is_pid_alive "${pid}"; then
        kill -9 "${pid}" >/dev/null 2>&1 || true
      fi
      killed=1
    fi
  done

  if [[ "${killed}" -eq 1 ]]; then
    echo "Stopped existing kubectl listener on port ${port}."
  fi
}

start_one() {
  local name="$1"
  local pid_file="$2"
  local log_file="$3"
  local local_port="$4"
  local target="$5"
  local target_port="$6"

  if [[ -f "${pid_file}" ]]; then
    local old_pid
    old_pid="$(cat "${pid_file}")"
    if is_pid_alive "${old_pid}"; then
      echo "${name} port-forward already running (pid ${old_pid})."
      return 0
    fi
    rm -f "${pid_file}"
  fi

  if port_in_use "${local_port}"; then
    echo "Port ${local_port} is already in use. Stop existing forward or choose another port."
    exit 1
  fi

  nohup kubectl port-forward -n "${NAMESPACE}" "${target}" "${local_port}:${target_port}" >"${log_file}" 2>&1 &
  local pf_pid=$!

  sleep 1
  if ! is_pid_alive "${pf_pid}"; then
    echo "Failed to start ${name} port-forward. See ${log_file}"
    exit 1
  fi

  echo "${pf_pid}" >"${pid_file}"
  echo "Started ${name} port-forward: localhost:${local_port} -> ${target}:${target_port} (pid ${pf_pid})"
}

stop_one() {
  local name="$1"
  local pid_file="$2"
  local local_port="$3"

  if [[ -f "${pid_file}" ]]; then
    local pid
    pid="$(cat "${pid_file}")"
    if is_pid_alive "${pid}"; then
      kill "${pid}" >/dev/null 2>&1 || true
      sleep 1
      if is_pid_alive "${pid}"; then
        kill -9 "${pid}" >/dev/null 2>&1 || true
      fi
    fi
    rm -f "${pid_file}"
  fi

  # Also clean up manual kubectl forwards that used the same port.
  kill_kubectl_listener_by_port "${local_port}"

  echo "Stopped ${name} port-forward."
}

status_one() {
  local name="$1"
  local pid_file="$2"
  local local_port="$3"
  local target="$4"
  local target_port="$5"

  if [[ -f "${pid_file}" ]]; then
    local pid
    pid="$(cat "${pid_file}")"
    if is_pid_alive "${pid}"; then
      echo "${name}: running (pid ${pid}) localhost:${local_port} -> ${target}:${target_port}"
      return
    fi
  fi

  echo "${name}: stopped"
}

action="${1:-}"
target="${2:-}"

if [[ -z "${action}" ]]; then
  usage
  exit 1
fi

case "${action}" in
  start)
    case "${target}" in
      app)
        start_one "app" "${APP_PID_FILE}" "${APP_LOG_FILE}" "${APP_LOCAL_PORT}" "${APP_TARGET}" "${APP_TARGET_PORT}"
        ;;
      collector)
        start_one "collector" "${COL_PID_FILE}" "${COL_LOG_FILE}" "${COL_LOCAL_PORT}" "${COL_TARGET}" "${COL_TARGET_PORT}"
        ;;
      all)
        start_one "app" "${APP_PID_FILE}" "${APP_LOG_FILE}" "${APP_LOCAL_PORT}" "${APP_TARGET}" "${APP_TARGET_PORT}"
        start_one "collector" "${COL_PID_FILE}" "${COL_LOG_FILE}" "${COL_LOCAL_PORT}" "${COL_TARGET}" "${COL_TARGET_PORT}"
        ;;
      *)
        usage
        exit 1
        ;;
    esac
    ;;
  stop)
    case "${target}" in
      app)
        stop_one "app" "${APP_PID_FILE}" "${APP_LOCAL_PORT}"
        ;;
      collector)
        stop_one "collector" "${COL_PID_FILE}" "${COL_LOCAL_PORT}"
        ;;
      all)
        stop_one "app" "${APP_PID_FILE}" "${APP_LOCAL_PORT}"
        stop_one "collector" "${COL_PID_FILE}" "${COL_LOCAL_PORT}"
        ;;
      *)
        usage
        exit 1
        ;;
    esac
    ;;
  status)
    status_one "app" "${APP_PID_FILE}" "${APP_LOCAL_PORT}" "${APP_TARGET}" "${APP_TARGET_PORT}"
    status_one "collector" "${COL_PID_FILE}" "${COL_LOCAL_PORT}" "${COL_TARGET}" "${COL_TARGET_PORT}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
