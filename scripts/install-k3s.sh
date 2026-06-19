#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}[setup]${NC} $*"; }

# ── install k3s and helm in parallel ─────────────────────────────────────────
info "Installing k3s + Helm in parallel..."

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik --disable=servicelb --disable=metrics-server" sh - &
K3S_PID=$!

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash &
HELM_PID=$!

wait $K3S_PID && info "k3s installed"
wait $HELM_PID && info "Helm installed"

# ── configure kubectl ─────────────────────────────────────────────────────────
mkdir -p ~/.kube
k3s kubectl config view --raw > ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc

# ── wait for node ready (no fixed sleep) ─────────────────────────────────────
info "Waiting for node to be Ready..."
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 1; done
info "Node ready. Run: make deploy"
