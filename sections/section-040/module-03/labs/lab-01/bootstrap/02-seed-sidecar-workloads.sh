#!/usr/bin/env bash
# UNTESTED: written without running it.
set -eu

# Sidecar-mode namespace: the injection label is set BEFORE the pods are created.
kubectl create namespace sidecar-shop --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace sidecar-shop istio-injection=enabled --overwrite
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: sidecar-shop
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
  namespace: sidecar-shop
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
  namespace: sidecar-shop
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
kubectl -n sidecar-shop wait --for=condition=Available deployment --all --timeout=300s

# Record the pod UIDs. The migration must create the pods again, so the grader
# checks that none of these UIDs is still running.
uids=$(kubectl -n sidecar-shop get pods \
  -o jsonpath='{range .items[*]}{.metadata.name}={.metadata.uid}{"\n"}{end}' | sort)
kubectl -n sidecar-shop create configmap lab-baseline \
  --from-literal=pod-uids="$uids" --dry-run=client -o yaml | kubectl apply -f -
echo "sidecar-shop runs in sidecar mode (two containers per pod)."
