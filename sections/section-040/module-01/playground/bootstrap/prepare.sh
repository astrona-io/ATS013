#!/usr/bin/env bash
# OS prep for the "Install Istio In Ambient Mode" playground.
# Environment preparation only: install istioctl and the ambient profile, then
# create an UNENROLLED namespace with two workloads. Enrolling the namespace
# and proving ztunnel took over is the module's subject, so the dataplane-mode
# label is deliberately not set here.
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

echo "[playground] Installing the ambient profile (istiod + istio-cni + ztunnel)..."
istioctl install --set profile=ambient -y
kubectl -n istio-system wait --for=condition=Available deployment/istiod --timeout=300s
kubectl -n istio-system rollout status daemonset/ztunnel --timeout=300s
kubectl -n istio-system rollout status daemonset/istio-cni-node --timeout=300s

echo "[playground] Creating namespace ambient-demo (NOT enrolled) with two workloads..."
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: ambient-demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service-v1
  namespace: ambient-demo
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
  namespace: ambient-demo
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
  namespace: ambient-demo
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

kubectl -n ambient-demo wait --for=condition=Available deployment --all --timeout=300s

echo "[playground] Starting state — ztunnel and istio-cni run per node, pods have one container,"
echo "[playground] and ambient-demo carries no dataplane-mode label yet:"
kubectl -n istio-system get daemonset
kubectl get ns ambient-demo --show-labels
kubectl -n ambient-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
