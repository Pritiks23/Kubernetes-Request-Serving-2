export KUBECONFIG := $(HOME)/.kube/config

.PHONY: install deploy smoke-test port-forward logs status teardown

install:
	@bash scripts/install-k3s.sh

deploy:
	@bash scripts/deploy.sh

smoke-test:
	@bash scripts/smoke-test.sh

port-forward:
	@echo "Starting port-forwards (Ctrl-C to stop all)..."
	kubectl port-forward svc/vllm-service -n inference 8000:8000 &
	kubectl port-forward svc/grafana -n monitoring 3000:3000 &
	kubectl port-forward svc/prometheus -n monitoring 9090:9090 &
	@wait

logs:
	kubectl logs -n inference -l app=vllm -f --tail=50

status:
	@echo "=== Nodes ===" && kubectl get nodes
	@echo "" && echo "=== Inference pods ===" && kubectl get pods -n inference -o wide
	@echo "" && echo "=== Monitoring pods ===" && kubectl get pods -n monitoring -o wide

teardown:
	kubectl delete namespace inference --ignore-not-found
	kubectl delete namespace monitoring --ignore-not-found
