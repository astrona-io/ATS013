#!/usr/bin/env bash
# OS prep for the "Install Istio With Helm" playground.
# Environment preparation only: install helm and istioctl, register the Istio
# chart repository, and leave the cluster clean. The three chart installs are
# what the module is about, so this script does not run them.
set -euo pipefail

ISTIO_VERSION="1.30.5"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[playground] Downloading Istio ${ISTIO_VERSION} (for istioctl, used only to verify)..."
(cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"

if ! command -v helm >/dev/null 2>&1; then
  echo "[playground] Installing helm 3..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | HELM_INSTALL_DIR="$BIN_DIR" USE_SUDO=false bash
fi

echo "[playground] Adding the Istio chart repository..."
helm repo add istio https://istio-release.storage.googleapis.com/charts >/dev/null
helm repo update >/dev/null

echo "[playground] Ready:"
helm version --short
"$BIN_DIR/istioctl" version --remote=false
# `| head` closes the pipe early, and under `pipefail` the SIGPIPE it sends to
# helm fails the whole script (exit 141). Limit the output with helm itself.
helm search repo istio --versions --max-col-width 0 | sed -n '1,5p'

echo "[playground] No chart is installed. 'helm ls -A' is empty and there are no Istio CRDs."
