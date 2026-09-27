#!/usr/bin/env bash
set -eu

ISTIO_CURRENT="1.29.8"
ISTIO_TARGET="1.30.5"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for v in "$ISTIO_CURRENT" "$ISTIO_TARGET"; do
  echo "Downloading Istio ${v}..."
  (cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$v" sh -)
  install -m 0755 "$WORK/istio-${v}/bin/istioctl" "$BIN_DIR/istioctl-${v}"
done
# Plain `istioctl` is the version that is installed.
ln -sf "$BIN_DIR/istioctl-${ISTIO_CURRENT}" "$BIN_DIR/istioctl"

if ! command -v helm >/dev/null 2>&1; then
  echo "Installing helm 3..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | HELM_INSTALL_DIR="$BIN_DIR" USE_SUDO=false bash
fi

helm repo add istio https://istio-release.storage.googleapis.com/charts >/dev/null
helm repo update >/dev/null

echo "istioctl        -> ${ISTIO_CURRENT} (what will be installed)"
echo "istioctl-${ISTIO_TARGET} -> ${ISTIO_TARGET} (the upgrade target)"
