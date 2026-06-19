#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=~/.kube/config
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[deploy]${NC} $*"; }
warn() { echo -e "${YELLOW}[deploy]${NC} $*"; }
die()  { echo -e "${RED}[deploy]${NC} $*" >&2; exit 1; }

kubectl cluster-info &>/dev/null || die "Cannot reach cluster — run: make install"

info "Creating namespaces..."
kubectl apply -f k8s/namespace.yaml

info "Applying RBAC..."
kubectl apply -f k8s/rbac/prometheus-rbac.yaml

info "Applying vLLM config..."
kubectl apply -f k8s/configmap.yaml

info "Deploying vLLM..."
kubectl apply -f k8s/vllm-deployment.yaml
kubectl apply -f k8s/vllm-service.yaml

info "Deploying inference router..."
kubectl apply -f k8s/inference-router.yaml

info "Deploying API gateway..."
kubectl apply -f k8s/api-gateway.yaml

info "Deploying monitoring stack..."
kubectl apply -f k8s/monitoring/

info "Waiting for vLLM (downloads ~250MB model on first run — ~2 min)..."
kubectl rollout status deployment/vllm -n inference --timeout=300s || {
  warn "vLLM timed out. Logs:"
  kubectl logs -n inference -l app=vllm --tail=20 || true
  die "Deploy failed — check logs above"
}

info "Waiting for Prometheus..."
kubectl rollout status deployment/prometheus -n monitoring --timeout=120s

info "Waiting for Grafana..."
kubectl rollout status deployment/grafana -n monitoring --timeout=120s

echo ""
info "Everything is running!"
info ""
info "Next step:  make smoke-test"
info ""
info "Port-forwards:"
info "  make port-forward"
info ""
info "Or manually:"
info "  kubectl port-forward svc/vllm-service  -n inference  8000:8000"
info "  kubectl port-forward svc/grafana       -n monitoring 3000:3000"
info "  kubectl port-forward svc/prometheus    -n monitoring 9090:9090"
