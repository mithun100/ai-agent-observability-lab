# Local Kubernetes Workflow (Docker Desktop Only)

This folder documents the local hybrid Kubernetes workflow.

Scope:
- Intended for local Docker Desktop Kubernetes only.
- Not intended for EKS, GKE, or AKS.

Why:
- Local workflow uses host bridge endpoints and local port-forwarding.
- Managed clusters should use cluster-native services, ingress, and cloud secret management.

Local-only helper:
- scripts/k8s-forward-local.sh

Examples:
- Start app and collector forwards:
  - scripts/k8s-forward-local.sh start all
- Check status:
  - scripts/k8s-forward-local.sh status
- Stop all forwards:
  - scripts/k8s-forward-local.sh stop all

Forward mappings:
- App API: localhost:18080 -> travel-planner:8080
- Collector metrics bridge: localhost:19464 -> otel-collector:9464
