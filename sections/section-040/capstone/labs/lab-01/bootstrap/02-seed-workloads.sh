#!/usr/bin/env bash
set -eu

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: ambient-shop
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-api
  namespace: ambient-shop
  labels:
    app: catalog-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog-api
  template:
    metadata:
      labels:
        app: catalog-api
    spec:
      containers:
        - name: catalog-api
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: catalog-api
  namespace: ambient-shop
spec:
  selector:
    app: catalog-api
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storefront
  namespace: ambient-shop
  labels:
    app: storefront
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storefront
  template:
    metadata:
      labels:
        app: storefront
    spec:
      containers:
        - name: storefront
          image: curlimages/curl:8.11.1
          command: ["sh", "-c", "while true; do sleep 30; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-runner
  namespace: ambient-shop
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
          image: curlimages/curl:8.11.1
          command: ["sh", "-c", "while true; do sleep 30; done"]
YAML

kubectl -n ambient-shop wait --for=condition=Available deployment --all --timeout=300s

uids=$(kubectl -n ambient-shop get pods \
  -o jsonpath='{range .items[*]}{.metadata.name}={.metadata.uid}{"\n"}{end}' | sort)
kubectl -n ambient-shop create configmap lab-baseline \
  --from-literal=pod-uids="$uids" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Baseline pod UIDs recorded in configmap ambient-shop/lab-baseline:"
echo "$uids"
echo "ambient-shop is NOT enrolled. Every pod has exactly one container."
