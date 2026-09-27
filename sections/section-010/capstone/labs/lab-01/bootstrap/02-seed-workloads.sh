#!/usr/bin/env bash
set -eu

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: payments
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkout-api
  namespace: payments
  labels:
    app: checkout-api
spec:
  replicas: 1
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
  name: legacy
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-runner
  namespace: legacy
  labels:
    app: batch-runner
spec:
  replicas: 1
  selector:
    matchLabels:
      app: batch-runner
  template:
    metadata:
      labels:
        app: batch-runner
    spec:
      containers:
        - name: batch-runner
          image: busybox:1.36
          command: ["sh", "-c", "while true; do sleep 30; done"]
YAML

kubectl -n payments rollout status deployment/checkout-api --timeout=180s
kubectl -n legacy rollout status deployment/batch-runner --timeout=180s

echo "payments/checkout-api and legacy/batch-runner are running, both unmeshed, neither namespace labelled."
