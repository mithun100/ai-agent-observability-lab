# Travel Agent Observability Lab

Multi-agent travel planner instrumented with OpenTelemetry.
This repository is structured for public use with a single canonical runtime path.

## Canonical Structure

- app/: application source code
- observability/: collector profiles, Docker stack, Kubernetes manifests, smoke validation
- scripts/: helper scripts
- archive/: deprecated or legacy folders kept for reference only

## What To Use

Use observability/ for all active local and Kubernetes workflows.
Do not use folders under archive/ for normal runs.

## Prerequisites

- Docker Desktop with Docker Compose v2
- Optional: kubectl + local Kubernetes (for k8s validation)
- Credentials in .env for your chosen LLM backend

## Setup

1. Create environment file:

```bash
cp .env.example .env
```

2. Edit .env and set at minimum:

- LLM_BACKEND (bedrock, azure, or nim)
- For Bedrock:
  - AWS_ACCESS_KEY_ID
  - AWS_SECRET_ACCESS_KEY
  - AWS_DEFAULT_REGION
  - AWS_BEDROCK_MODEL_ID
- Optional observability vars:
  - OBSERVABILITY_BACKEND (oss, splunk, thirdparty)

## Run Locally (Canonical)

Recommended (short commands):

```bash
./scripts/stack.sh up
./scripts/stack.sh ps
./scripts/stack.sh health
./scripts/stack.sh test
./scripts/stack.sh logs
./scripts/stack.sh down
```

Direct docker compose form (equivalent):

Start stack:

```bash
docker compose --env-file .env -f observability/docker/docker-compose.yaml up -d --build
```

Stop stack:

```bash
docker compose --env-file .env -f observability/docker/docker-compose.yaml down
```

Check services:

```bash
docker compose --env-file .env -f observability/docker/docker-compose.yaml ps
```

Tail logs:

```bash
docker compose --env-file .env -f observability/docker/docker-compose.yaml logs -f
```

## Functional Check

Send a request:

```bash
curl -sS -X POST http://localhost:8080/travel/plan \
  -H "Content-Type: application/json" \
  -d '{"source":"Bengaluru","destination":"Tokyo","date":"2026-12-10"}'
```

Expected:

- HTTP 200 response
- itinerary-style JSON payload

## Telemetry Check (OSS)

- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Tempo API health: http://localhost:3200/ready
- Loki API health: http://localhost:3100/ready

Example metrics query:

```bash
curl -s "http://localhost:9090/api/v1/query?query=gen_ai_client_operation_duration_seconds_count"
```

## Switch Observability Backend

OSS:

```bash
export OBSERVABILITY_BACKEND=oss
docker compose --env-file .env -f observability/docker/docker-compose.yaml down
docker compose --env-file .env -f observability/docker/docker-compose.yaml up -d --build
```

Splunk:

```bash
export OBSERVABILITY_BACKEND=splunk
docker compose --env-file .env -f observability/docker/docker-compose.yaml down
docker compose --env-file .env -f observability/docker/docker-compose.yaml up -d --build
```

Third-party OTLP:

```bash
export OBSERVABILITY_BACKEND=thirdparty
docker compose --env-file .env -f observability/docker/docker-compose.yaml down
docker compose --env-file .env -f observability/docker/docker-compose.yaml up -d --build
```

## Smoke Validation Script

```bash
chmod +x observability/smoke/validate_backend.sh
OBSERVABILITY_BACKEND=oss ./observability/smoke/validate_backend.sh
```

## Kubernetes (Local)

Important scope note:

- This section is for local Docker Desktop Kubernetes only.
- Do not use this local hybrid port-forward pattern for EKS, GKE, or AKS.

Bootstrap Bedrock secret and local image first:

```bash
chmod +x scripts/k8s-secrets.sh
./scripts/k8s-secrets.sh
docker build -t travel-planner:latest app
```

Deploy OSS overlay:

```bash
kubectl apply -k observability/k8s/overlays/oss
```

Check rollout:

```bash
kubectl get pods
kubectl get svc
```

Test app via port-forward:

```bash
chmod +x scripts/k8s-forward-local.sh
./scripts/k8s-forward-local.sh start all
./scripts/k8s-forward-local.sh status
```

In another terminal:

```bash
curl -sS -X POST http://localhost:18080/travel/plan \
  -H "Content-Type: application/json" \
  -d '{"source":"Seattle","destination":"Tokyo","date":"2026-12-10"}'
```

Stop local forwards when done:

```bash
./scripts/k8s-forward-local.sh stop all
```

## Notes For Public Repo

- Keep app code in app/ and runtime wiring in observability/
- Keep archive/ for historical reference only
- Prefer one quickstart path to reduce onboarding confusion

