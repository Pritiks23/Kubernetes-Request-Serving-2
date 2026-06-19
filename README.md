# GPU Inference Platform

A production-style Kubernetes platform for serving LLMs at scale — featuring an API gateway, inference router, vLLM serving engine, and a full Prometheus + Grafana observability stack.

Runs entirely inside a **GitHub Codespace** (no GPU, no cloud account needed for the demo).

## Architecture

```
Users
  │
  ▼
┌─────────────────┐
│   API Gateway   │  Rate limiting, request routing, headers
│   (nginx)       │  NodePort :30080
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Inference Router│  Load balancing across vLLM replicas
│   (nginx)       │  ClusterIP :80
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     vLLM        │  OpenAI-compatible /v1 API
│ facebook/opt-   │  ClusterIP :8000
│    125m         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   GPU Nodes     │  nvidia.com/gpu resource scheduling
│  (CPU in demo)  │  --device=cpu for Codespaces
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Prometheus    │  Scrapes vLLM /metrics every 15s
│   :9090         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Grafana      │  Dashboards — latency, throughput, errors
│   :3000         │  admin / demo1234
└─────────────────┘
```

## Quickstart (GitHub Codespaces)

**1. Open in Codespace**

Click the green **Code** button → **Codespaces** → **Create codespace on main**.

The devcontainer will automatically install k3s and Helm when it starts (~2 min).

**2. Deploy everything**

```bash
make deploy
```

**3. Run the smoke test**

```bash
make smoke-test
```

**4. Open the UIs**

Codespaces will prompt you to open forwarded ports, or run:

```bash
make port-forward
```

| Service    | URL                      | Credentials     |
|------------|--------------------------|-----------------|
| vLLM API   | http://localhost:8000    | none            |
| Grafana    | http://localhost:3000    | admin / demo1234|
| Prometheus | http://localhost:9090    | none            |

## Try the API

```bash
# List loaded models
curl http://localhost:8000/v1/models

# Run a completion
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "facebook/opt-125m",
    "prompt": "Kubernetes is a platform for",
    "max_tokens": 30
  }'
```

## Swap the model

Edit `k8s/configmap.yaml` and change `MODEL_ID`. No token needed for:

| Model | Size | Notes |
|-------|------|-------|
| `facebook/opt-125m` | 250MB | Default, fastest |
| `facebook/opt-350m` | 700MB | Slightly better quality |
| `TinyLlama/TinyLlama-1.1B-Chat-v1.0` | 2.2GB | Chat-tuned, no token |

Then redeploy:
```bash
kubectl rollout restart deployment/vllm -n inference
```

## Repository structure

```
├── .devcontainer.json          # Codespaces config — auto-installs k3s
├── Makefile                    # install / deploy / smoke-test / teardown
├── scripts/
│   ├── install-k3s.sh         # Installs k3s + Helm
│   ├── deploy.sh              # Ordered kubectl apply + rollout waits
│   └── smoke-test.sh          # Hits /v1/models and /v1/completions
└── k8s/
    ├── namespace.yaml          # inference + monitoring namespaces
    ├── configmap.yaml          # Model ID, serving args (no secrets needed)
    ├── vllm-deployment.yaml    # vLLM — cpu mode for Codespaces, gpu for prod
    ├── vllm-service.yaml       # ClusterIP :8000
    ├── inference-router.yaml   # nginx router + service
    ├── api-gateway.yaml        # nginx gateway, rate limiting, NodePort :30080
    ├── monitoring/
    │   ├── prometheus.yaml     # Prometheus + scrape config for vLLM
    │   └── grafana.yaml        # Grafana + Prometheus datasource provisioning
    └── rbac/
        └── prometheus-rbac.yaml # ServiceAccount + ClusterRole for pod discovery
```

## Production path

To move from demo to production:

1. **GPU nodes** — remove `--device=cpu` from `vllm-deployment.yaml`, add `nvidia.com/gpu: "1"` resource limit
2. **Model** — set `MODEL_ID` to your target model, add `HF_TOKEN` secret for gated models
3. **Replicas** — increase `replicas` on api-gateway and inference-router
4. **Storage** — add a `PersistentVolumeClaim` so model weights survive pod restarts
5. **TLS** — add cert-manager + ingress with TLS termination
