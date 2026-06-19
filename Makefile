export KUBECONFIG := $(HOME)/.kube/config

.PHONY: install deploy smoke-test port-forward logs status teardown wait-ready

install:
	@bash scripts/install-k3s.sh

deploy:
	@bash scripts/deploy.sh

smoke-test:
	@bash scripts/smoke-test.sh

# Forward all service ports to localhost.
# Runs in the foreground; Ctrl-C stops all tunnels.
port-forward:
	@echo "Starting port-forwards — press Ctrl-C to stop."
	@echo "  vLLM API  → http://localhost:8000"
	@echo "  Grafana   → http://localhost:3000  (admin / demo1234)"
	@echo "  Prometheus→ http://localhost:9090"
	@trap 'kill 0' INT; \
	  kubectl port-forward svc/vllm-service   -n inference  8000:8000 & \
	  kubectl port-forward svc/grafana        -n monitoring 3000:3000 & \
	  kubectl port-forward svc/prometheus     -n monitoring 9090:9090 & \
	  wait

logs:
	kubectl logs -n inference -l app=vllm -f --tail=50

status:
	@echo "=== Nodes ==="
	@kubectl get nodes -o wide
	@echo ""
	@echo "=== Inference pods ==="
	@kubectl get pods -n inference -o wide
	@echo ""
	@echo "=== Monitoring pods ==="
	@kubectl get pods -n monitoring -o wide
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc -n inference
	@kubectl get svc -n monitoring

# Block until all pods in both namespaces are Running/Ready.
wait-ready:
	@echo "Waiting for all inference pods..."
	@kubectl wait --for=condition=Ready pods --all -n inference  --timeout=600s
	@echo "Waiting for all monitoring pods..."
	@kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=180s
	@echo "All pods ready."

teardown:
	kubectl delete namespace inference  --ignore-not-found
	kubectl delete namespace monitoring --ignore-not-found
