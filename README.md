# Travel Agent Observability Lab

Multi-agent travel planner instrumented with OpenTelemetry.
This repository is structured for public use with a single canonical runtime path.

## Canonical Structure

- app/: application source code
- observability/: Docker stack and telemetry dashboards
- scripts/: helper scripts

## What To Use

Use observability/ for the active local Docker workflow.

## Prerequisites

- Docker Desktop with Docker Compose v2
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
  -d '{"origin":"Bengaluru","destination":"Tokyo","travellers":2}'
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
