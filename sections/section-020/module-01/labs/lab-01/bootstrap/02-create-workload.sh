#!/usr/bin/env bash
set -eu

kubectl create namespace mesh-demo --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace mesh-demo istio-injection=enabled --overwrite

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: mesh-demo
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
    spec:
      containers:
        - name: notification-service
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
YAML

kubectl -n mesh-demo rollout status deployment/notification-service --timeout=180s

echo "mesh-demo is meshed and running one injected workload."
