#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

BASE_URL="http://localhost:8000"
MAX_WAIT=120
INTERVAL=5

echo "==> Smoke test: waiting for vLLM API to be reachable at $BASE_URL ..."

elapsed=0
until curl -sf "$BASE_URL/v1/models" > /dev/null 2>&1; do
  if [ "$elapsed" -ge "$MAX_WAIT" ]; then
    echo "ERROR: vLLM API did not become reachable within ${MAX_WAIT}s."
    echo "       Check pod status: kubectl get pods -n inference"
    echo "       Check pod logs:   kubectl logs -n inference -l app=vllm --tail=40"
    exit 1
  fi
  echo "  ... not ready yet (${elapsed}s elapsed), retrying in ${INTERVAL}s"
  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done

echo ""
echo "==> Test 1: GET /v1/models"
MODELS=$(curl -sf "$BASE_URL/v1/models")
echo "$MODELS" | python3 -m json.tool 2>/dev/null || echo "$MODELS"

MODEL_ID=$(echo "$MODELS" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['id'])" 2>/dev/null || echo "facebook/opt-125m")
echo "    Detected model: $MODEL_ID"

echo ""
echo "==> Test 2: POST /v1/completions"
RESPONSE=$(curl -sf "$BASE_URL/v1/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$MODEL_ID\",
    \"prompt\": \"Kubernetes is a platform for\",
    \"max_tokens\": 20
  }")
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

COMPLETION=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['choices'][0]['text'])" 2>/dev/null || echo "(could not parse)")
echo ""
echo "==> Completion text: $COMPLETION"
echo ""
echo "==> Smoke test PASSED"
