#!/usr/bin/env bash
# OS prep for the "Canary Upgrade With Revisions And Revision Tags" playground.
# Environment preparation only: two istioctl binaries (1.29.8 = the installed
# version, 1.30.5 = the upgrade target), Istio 1.29.8 installed as the default
# unrevisioned control plane, and one injected workload in canary-demo.
# Installing the second revision is the module's subject and is left to you.
set -euo pipefail

ISTIO_CURRENT="1.29.8"
ISTIO_TARGET="1.30.5"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for v in "$ISTIO_CURRENT" "$ISTIO_TARGET"; do
  echo "[playground] Downloading Istio ${v}..."
  (cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$v" sh -)
  install -m 0755 "$WORK/istio-${v}/bin/istioctl" "$BIN_DIR/istioctl-${v}"
done
# Plain `istioctl` is the CURRENTLY INSTALLED version. The target version is
# only reachable as istioctl-1.30.5, so you cannot upgrade by accident.
ln -sf "$BIN_DIR/istioctl-${ISTIO_CURRENT}" "$BIN_DIR/istioctl"

echo "[playground] Installing Istio ${ISTIO_CURRENT} as the default revision..."
istioctl install --set profile=demo -y
kubectl -n istio-system wait --for=condition=Available deployment --all --timeout=300s

echo "[playground] Creating namespace canary-demo, labelled for the default control plane..."
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: canary-demo
  labels:
    istio-injection: enabled
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service-v1
  namespace: canary-demo
  labels:
    app: notification-service
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notification-service
      version: v1
  template:
    metadata:
      labels:
        app: notification-service
        version: v1
    spec:
      containers:
        - name: notification-service
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: notification-service
  namespace: canary-demo
spec:
  selector:
    app: notification-service
  ports:
    - name: http
      port: 80
      targetPort: 80
YAML

kubectl -n canary-demo wait --for=condition=Available deployment/notification-service-v1 --timeout=300s

echo "[playground] Starting state — exactly one istiod, no revision suffix:"
kubectl -n istio-system get pods -l app=istiod
echo "[playground] istioctl        -> ${ISTIO_CURRENT} (what is installed)"
echo "[playground] istioctl-${ISTIO_TARGET} -> ${ISTIO_TARGET} (the upgrade target)"
