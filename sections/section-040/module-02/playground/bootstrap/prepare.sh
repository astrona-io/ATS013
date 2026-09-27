#!/usr/bin/env bash
# OS prep for the "Add A Waypoint Proxy For L7 In Ambient Mode" playground.
# Environment preparation only: ambient Istio, the Gateway API CRDs, and an
# ambient-ENROLLED namespace with two workloads. There is no waypoint and no
# HTTPRoute: creating those is the module's subject.
set -euo pipefail

ISTIO_VERSION="1.30.5"
GATEWAY_API_VERSION="v1.5.1"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[playground] Downloading Istio ${ISTIO_VERSION}..."
(cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -)
install -m 0755 "$WORK/istio-${ISTIO_VERSION}/bin/istioctl" "$BIN_DIR/istioctl"

echo "[playground] Installing the Gateway API CRDs ${GATEWAY_API_VERSION}..."
# A waypoint IS a Gateway. Without these CRDs `istioctl waypoint apply` fails
# with an unknown-kind error that looks like an Istio bug but is not.
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"

echo "[playground] Installing the ambient profile..."
istioctl install --set profile=ambient -y
kubectl -n istio-system wait --for=condition=Available deployment/istiod --timeout=300s
kubectl -n istio-system rollout status daemonset/ztunnel --timeout=300s
kubectl -n istio-system rollout status daemonset/istio-cni-node --timeout=300s

echo "[playground] Creating namespace ambient-l7, already enrolled in ambient mode..."
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: ambient-l7
  labels:
    istio.io/dataplane-mode: ambient
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service-v1
  namespace: ambient-l7
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
  namespace: ambient-l7
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
  namespace: ambient-l7
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

kubectl -n ambient-l7 wait --for=condition=Available deployment --all --timeout=300s

echo "[playground] Starting state — L4 mesh is on, no Gateway exists:"
kubectl get ns ambient-l7 --show-labels
kubectl -n ambient-l7 get gateway 2>&1 | tail -1
