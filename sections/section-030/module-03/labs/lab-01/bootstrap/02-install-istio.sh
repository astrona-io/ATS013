#!/usr/bin/env bash
set -eu

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
export PATH="$BIN_DIR:$PATH"

echo "Installing Istio 1.29.8 with the default profile..."
istioctl install --set profile=default -y
kubectl -n istio-system wait --for=condition=Available deployment --all --timeout=300s

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

echo "Starting state - control plane and every proxy on 1.29.8:"
istioctl version
