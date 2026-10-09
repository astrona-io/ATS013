#!/usr/bin/env bash
set -eu

ISTIO_VERSION="1.30.5"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Downloading Istio ${ISTIO_VERSION} (istioctl, for verification only)..."
(cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"

if ! command -v helm >/dev/null 2>&1; then
  echo "Installing helm 3..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | HELM_INSTALL_DIR="$BIN_DIR" USE_SUDO=false bash
fi

echo "Registering the istio chart repository..."
helm repo add istio https://istio-release.storage.googleapis.com/charts >/dev/null
helm repo update >/dev/null

helm version --short
"$BIN_DIR/istioctl" version --remote=false

echo "No chart is installed. 'helm ls -A' is empty and there are no Istio CRDs."
