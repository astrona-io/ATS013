#!/usr/bin/env bash
# UNTESTED: written without running it.
set -eu

# The pods start BEFORE the namespace gets its injection label, so they have no
# sidecar. The VirtualService points at a host that does not exist.
kubectl create namespace shop --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: shop
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
  namespace: shop
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
  namespace: shop
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

kubectl -n shop wait --for=condition=Available deployment --all --timeout=300s

kubectl label namespace shop istio-injection=enabled --overwrite

kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: notification-route
  namespace: shop
spec:
  hosts:
    - notification-service
  http:
    - route:
        - destination:
            host: notification-svc
YAML
echo "shop: pods have no sidecar although the namespace is labelled, and notification-route points at a missing host."
