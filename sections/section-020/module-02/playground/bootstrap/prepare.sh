#!/usr/bin/env bash
# OS prep for the "Control Sidecar Injection" playground.
# Environment preparation only: install istioctl, install a default control
# plane, and create an UNLABELLED namespace with three workloads that have
# different injection needs. Deciding which of them gets a sidecar is the
# module's subject, so no injection label is set here.
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

echo "[playground] Installing the default control plane..."
istioctl install --set profile=default -y
kubectl -n istio-system wait --for=condition=Available deployment/istiod --timeout=300s

echo "[playground] Creating namespace inject-demo with three workloads (no injection label)..."
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: inject-demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: inject-demo
  labels:
    app: notification-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notification-service
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
  namespace: inject-demo
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
  name: logging-agent
  namespace: inject-demo
  labels:
    app: logging-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logging-agent
  template:
    metadata:
      labels:
        app: logging-agent
    spec:
      containers:
        - name: logging-agent
          image: busybox:1.36
          command: ["sh", "-c", "while true; do sleep 30; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-job
  namespace: inject-demo
  labels:
    app: batch-job
spec:
  replicas: 1
  selector:
    matchLabels:
      app: batch-job
  template:
    metadata:
      labels:
        app: batch-job
    spec:
      containers:
        - name: batch-job
          image: busybox:1.36
          command: ["sh", "-c", "while true; do sleep 30; done"]
YAML

kubectl -n inject-demo wait --for=condition=Available deployment --all --timeout=300s

echo "[playground] Starting state — namespace has no injection label, every pod has one container:"
kubectl get ns inject-demo --show-labels
kubectl -n inject-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
