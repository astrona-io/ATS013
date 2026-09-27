#!/usr/bin/env bash
set -eu

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
export PATH="$BIN_DIR:$PATH"

echo "Installing Istio 1.29.8 as the default revision (minimal profile)..."
istioctl install --set profile=minimal -y
kubectl -n istio-system wait --for=condition=Available deployment --all --timeout=300s

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: payments
  labels:
    istio-injection: enabled
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkout-api
  namespace: payments
  labels:
    app: checkout-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: checkout-api
  template:
    metadata:
      labels:
        app: checkout-api
    spec:
      containers:
        - name: checkout-api
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: checkout-api
  namespace: payments
spec:
  selector:
    app: checkout-api
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: Namespace
metadata:
  name: orders
  labels:
    istio-injection: enabled
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-api
  namespace: orders
  labels:
    app: order-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: order-api
  template:
    metadata:
      labels:
        app: order-api
    spec:
      containers:
        - name: order-api
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tester
  namespace: orders
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

kubectl -n payments wait --for=condition=Available deployment --all --timeout=300s
kubectl -n orders wait --for=condition=Available deployment --all --timeout=300s

echo "Starting state - one unrevisioned istiod at 1.29.8, two meshed namespaces:"
istioctl version
kubectl get ns payments orders --show-labels
