#!/usr/bin/env bash
set -eu

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
export PATH="$BIN_DIR:$PATH"

echo "Installing Istio 1.29.8 as the default revision..."
istioctl install --set profile=demo -y
kubectl -n istio-system wait --for=condition=Available deployment --all --timeout=300s

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

kubectl -n canary-demo rollout status deployment/notification-service-v1 --timeout=300s

echo "Starting state - exactly one istiod, no revision suffix:"
kubectl -n istio-system get pods -l app=istiod
