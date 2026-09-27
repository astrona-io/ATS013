#!/usr/bin/env bash
# OS prep for the "In-Place Upgrade Of The Control Plane" playground.
# Environment preparation only: two istioctl binaries (1.29.8 = installed,
# 1.30.5 = target), Istio 1.29.8 as the single default control plane, and a
# two-replica injected workload in inplace-demo so version skew is visible.
# The upgrade itself is the module's subject and is left to you.
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
ln -sf "$BIN_DIR/istioctl-${ISTIO_CURRENT}" "$BIN_DIR/istioctl"

echo "[playground] Installing Istio ${ISTIO_CURRENT} (default profile, default revision)..."
istioctl install --set profile=default -y
kubectl -n istio-system wait --for=condition=Available deployment --all --timeout=300s

echo "[playground] Creating namespace inplace-demo with two injected replicas..."
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: inplace-demo
  labels:
    istio-injection: enabled
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service-v1
  namespace: inplace-demo
  labels:
    app: notification-service
    version: v1
spec:
  replicas: 2
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
  namespace: inplace-demo
spec:
  selector:
    app: notification-service
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tester
  namespace: inplace-demo
  labels:
    app: tester
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tester
  template:
    metadata:
      labels:
        app: tester
    spec:
      containers:
        - name: tester
          image: curlimages/curl:8.11.1
          command: ["sh", "-c", "while true; do sleep 30; done"]
YAML

kubectl -n inplace-demo wait --for=condition=Available deployment --all --timeout=300s

echo "[playground] Starting state — control plane and every proxy on ${ISTIO_CURRENT}:"
istioctl version
echo "[playground] istioctl        -> ${ISTIO_CURRENT} (what is installed)"
echo "[playground] istioctl-${ISTIO_TARGET} -> ${ISTIO_TARGET} (the upgrade target)"
