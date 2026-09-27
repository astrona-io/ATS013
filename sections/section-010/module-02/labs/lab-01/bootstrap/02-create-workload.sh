#!/usr/bin/env bash
set -eu

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: mesh-demo
---
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
---
apiVersion: v1
kind: Service
metadata:
  name: notification-service
  namespace: mesh-demo
spec:
  selector:
    app: notification-service
  ports:
    - name: http
      port: 80
      targetPort: 80
YAML

kubectl -n mesh-demo rollout status deployment/notification-service --timeout=180s

echo "mesh-demo is ready: one workload, no injection label, one container per pod."
