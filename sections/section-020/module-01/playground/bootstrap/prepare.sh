#!/usr/bin/env bash
# OS prep for the "Customize An Istio Installation" playground.
# Environment preparation only: install istioctl and put a stock `demo` profile
# control plane on the cluster, so there is a known baseline to compare your
# own IstioOperator against. Writing that file is the module's subject and is
# left to you.
set -euo pipefail

ISTIO_VERSION="1.30.5"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[playground] Downloading Istio ${ISTIO_VERSION}..."
(cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"

echo "[playground] Installing the stock 'demo' profile as the baseline..."
istioctl install --set profile=demo -y

kubectl -n istio-system wait --for=condition=Available deployment --all --timeout=300s

echo "[playground] Baseline control plane is up:"
kubectl -n istio-system get deploy

echo "[playground] This is an unmodified 'demo' install — egress gateway present,"
echo "[playground] no access logging, no resource overrides. Everything you change"
echo "[playground] from here is a deviation you can diff against."
