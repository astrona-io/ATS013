#!/usr/bin/env bash
# OS prep for the "Install Istio With istioctl" playground.
# Environment preparation only: put the istioctl binary on the machine and
# leave the cluster completely untouched. Installing Istio is the whole point
# of the module, so this script deliberately does NOT install it.
set -euo pipefail

ISTIO_VERSION="1.30.5"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[playground] Downloading Istio ${ISTIO_VERSION}..."
(cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"

echo "[playground] istioctl ${ISTIO_VERSION} installed at ${BIN_DIR}/istioctl"
"$BIN_DIR/istioctl" version --remote=false

echo "[playground] The cluster is clean: no istio-system namespace, no Istio CRDs,"
echo "[playground] no injection webhook. That is the starting point for this module."
