#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing k3s..."

# Install k3s without Traefik (we use nginx), disable ServiceLB (not needed in Codespaces)
# --disable traefik        : we bring our own ingress/gateway
# --disable servicelb      : no cloud load balancer in Codespaces
# --write-kubeconfig-mode  : make kubeconfig world-readable so non-root works
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644" sh -

echo "==> Waiting for k3s to start..."
sleep 5
until k3s kubectl get nodes 2>/dev/null | grep -q "Ready"; do
  echo "  ... node not ready yet, retrying in 3s"
  sleep 3
done
echo "==> k3s node is Ready"

echo "==> Setting up kubeconfig at ~/.kube/config..."
mkdir -p "$HOME/.kube"
ln -sf /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"

echo "==> Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "==> k3s and Helm installation complete."
echo "    Run: make deploy"
