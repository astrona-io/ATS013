#!/usr/bin/env bash
set -eu

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: ambient-l7
  labels:
    istio.io/dataplane-mode: ambient
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: ambient-l7
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
  namespace: ambient-l7
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
  namespace: ambient-l7
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

kubectl -n ambient-l7 wait --for=condition=Available deployment --all --timeout=300s

echo "ambient-l7 is enrolled in ambient mode. L4 works; there is no waypoint and no HTTPRoute:"
kubectl get ns ambient-l7 --show-labels
kubectl -n ambient-l7 get gateway 2>&1 | tail -1
