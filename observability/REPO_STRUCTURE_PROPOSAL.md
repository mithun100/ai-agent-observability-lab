# Observability Repository Structure Proposal

This structure keeps instrumentation vendor-neutral and makes backend routing a deployment concern.

## Top-level

- `app/` — AI agent application code and OpenTelemetry SDK initialization.
- `observability/collector/profiles/` — Collector configuration profiles. Same receivers/processors, different exporters.
- `observability/docker/` — Local stack for OSS profile and backend profile switching.
- `observability/smoke/` — Smoke test scripts for traces/metrics/logs export validation.

## Collector Profile Files

- `collector-config.oss.yaml`
- `collector-config.splunk.yaml`
- `collector-config.thirdparty.yaml`

Each profile receives OTLP input from the app and differs only in exporter configuration.

## Why this layout

- Keeps application code unchanged when switching observability backends.
- Makes local Docker backend switching deterministic and scriptable.
- Separates platform concerns (collector export targets and secrets) from app logic.
