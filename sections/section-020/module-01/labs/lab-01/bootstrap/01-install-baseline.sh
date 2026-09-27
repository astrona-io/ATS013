#!/usr/bin/env bash
set -eu

ISTIO_VERSION="1.30.5"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Downloading Istio ${ISTIO_VERSION}..."
(cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"

echo "Installing the stock demo profile as the unmodified baseline..."
istioctl install --set profile=demo -y
kubectl -n istio-system wait --for=condition=Available deployment --all --timeout=300s

echo "Baseline is up. Every deviation from here is one you caused:"
kubectl -n istio-system get deploy
