#!/usr/bin/env bash
set -eu

ISTIO_CURRENT="1.29.8"
ISTIO_TARGET="1.30.5"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for v in "$ISTIO_CURRENT" "$ISTIO_TARGET"; do
  echo "Downloading Istio ${v}..."
  (cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$v" sh -)
  install -m 0755 "$WORK/istio-${v}/bin/istioctl" "$BIN_DIR/istioctl-${v}"
done
ln -sf "$BIN_DIR/istioctl-${ISTIO_CURRENT}" "$BIN_DIR/istioctl"

echo "istioctl        -> ${ISTIO_CURRENT} (what is installed)"
echo "istioctl-${ISTIO_TARGET} -> ${ISTIO_TARGET} (the upgrade target)"
