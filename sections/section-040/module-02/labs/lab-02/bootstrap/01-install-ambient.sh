#!/usr/bin/env bash
set -eu

ISTIO_VERSION="1.30.5"
GATEWAY_API_VERSION="v1.5.1"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Downloading Istio ${ISTIO_VERSION}..."
(cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"

# A waypoint IS a Gateway. Istio does not ship the Gateway API CRDs, so without
# these `istioctl waypoint apply` fails with an unknown-kind error.
echo "Installing the Gateway API CRDs ${GATEWAY_API_VERSION}..."
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"

echo "Installing the ambient profile..."
istioctl install --set profile=ambient -y
kubectl -n istio-system wait --for=condition=Available deployment/istiod --timeout=300s
kubectl -n istio-system rollout status daemonset/ztunnel --timeout=300s
kubectl -n istio-system rollout status daemonset/istio-cni-node --timeout=300s

echo "Ambient data plane and Gateway API CRDs are ready."
