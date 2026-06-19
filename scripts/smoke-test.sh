#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=~/.kube/config
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[test]${NC} $*"; }
fail() { echo -e "${RED}[test]${NC} $*"; exit 1; }

# Port-forward in background
kubectl port-forward svc/vllm-service -n inference 8000:8000 &
PF_PID=$!
sleep 3
trap "kill $PF_PID 2>/dev/null" EXIT

info "Checking /v1/models..."
MODELS=$(curl -sf http://localhost:8000/v1/models | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['id'])")
info "Model loaded: $MODELS"

info "Sending test completion..."
RESPONSE=$(curl -sf http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "facebook/opt-125m",
    "prompt": "Kubernetes is",
    "max_tokens": 20
  }' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['text'].strip())")

info "Response: $RESPONSE"
info "Smoke test passed!"
