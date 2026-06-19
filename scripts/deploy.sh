#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR/../k8s"

# Ensure kubeconfig is set (k3s writes here)
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

echo "==> Creating namespaces..."
kubectl apply -f "$K8S_DIR/namespace.yaml"

echo "==> Applying ConfigMap..."
kubectl apply -f "$K8S_DIR/configmap.yaml"

echo "==> Applying RBAC for Prometheus..."
kubectl apply -f "$K8S_DIR/rbac/prometheus-rbac.yaml"

echo "==> Deploying vLLM..."
kubectl apply -f "$K8S_DIR/vllm-deployment.yaml"
kubectl apply -f "$K8S_DIR/vllm-service.yaml"

echo "==> Deploying inference router..."
kubectl apply -f "$K8S_DIR/inference-router.yaml"

echo "==> Deploying API gateway..."
kubectl apply -f "$K8S_DIR/api-gateway.yaml"

echo "==> Deploying monitoring stack..."
kubectl apply -f "$K8S_DIR/monitoring/prometheus.yaml"
kubectl apply -f "$K8S_DIR/monitoring/grafana.yaml"

echo "==> Waiting for vLLM rollout (this may take a few minutes while the model downloads)..."
kubectl rollout status deployment/vllm -n inference --timeout=600s

echo "==> Waiting for inference-router rollout..."
kubectl rollout status deployment/inference-router -n inference --timeout=120s

echo "==> Waiting for api-gateway rollout..."
kubectl rollout status deployment/api-gateway -n inference --timeout=120s

echo "==> Waiting for Prometheus rollout..."
kubectl rollout status deployment/prometheus -n monitoring --timeout=120s

echo "==> Waiting for Grafana rollout..."
kubectl rollout status deployment/grafana -n monitoring --timeout=120s

echo ""
echo "==> All deployments are ready!"
echo "    Run: make smoke-test"
echo "    Run: make port-forward  (then open the forwarded ports in Codespaces)"
