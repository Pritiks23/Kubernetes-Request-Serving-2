#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}[setup]${NC} $*"; }

info "Installing k3s (lightweight Kubernetes)..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -

info "Waiting for k3s to be ready..."
sleep 10
until k3s kubectl get nodes | grep -q "Ready"; do sleep 3; done

info "Configuring kubectl..."
mkdir -p ~/.kube
k3s kubectl config view --raw > ~/.kube/config
chmod 600 ~/.kube/config

info "Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

info "k3s ready. Now run: bash scripts/deploy.sh"
