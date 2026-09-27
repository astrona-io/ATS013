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
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audit-shipper
  namespace: payments
  labels:
    app: audit-shipper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: audit-shipper
  template:
    metadata:
      labels:
        app: audit-shipper
    spec:
      containers:
        - name: audit-shipper
          image: busybox:1.36
          command: ["sh", "-c", "while true; do sleep 30; done"]
---
apiVersion: v1
kind: Namespace
metadata:
  name: legacy
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nightly-report
  namespace: legacy
  labels:
    app: nightly-report
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nightly-report
  template:
    metadata:
      labels:
        app: nightly-report
    spec:
      containers:
        - name: nightly-report
          image: busybox:1.36
          command: ["sh", "-c", "while true; do sleep 30; done"]
YAML

kubectl -n payments wait --for=condition=Available deployment --all --timeout=300s
kubectl -n legacy wait --for=condition=Available deployment --all --timeout=300s

echo "payments holds checkout-api and audit-shipper; legacy holds nightly-report. Nothing is meshed and neither namespace is labelled."
