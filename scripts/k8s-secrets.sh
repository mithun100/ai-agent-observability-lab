#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
NAMESPACE="${1:-travel-observability}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Create it from .env.example first."
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

required_vars=(
  AWS_BEDROCK_MODEL_ID
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  AWS_DEFAULT_REGION
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required variable in .env: ${var_name}"
    exit 1
  fi
done

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic app-llm-secrets \
  -n "${NAMESPACE}" \
  --from-literal=AWS_BEDROCK_MODEL_ID="${AWS_BEDROCK_MODEL_ID}" \
  --from-literal=AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
  --from-literal=AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
  --from-literal=AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Created/updated secret app-llm-secrets in namespace ${NAMESPACE}."
