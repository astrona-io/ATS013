#!/usr/bin/env bash
set -eu

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: inject-demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: inject-demo
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
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logging-agent
  namespace: inject-demo
  labels:
    app: logging-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logging-agent
  template:
    metadata:
      labels:
        app: logging-agent
    spec:
      containers:
        - name: logging-agent
          image: busybox:1.36
          command: ["sh", "-c", "while true; do sleep 30; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-job
  namespace: inject-demo
  labels:
    app: batch-job
spec:
  replicas: 1
  selector:
    matchLabels:
      app: batch-job
  template:
    metadata:
      labels:
        app: batch-job
    spec:
      containers:
        - name: batch-job
          image: busybox:1.36
          command: ["sh", "-c", "while true; do sleep 30; done"]
YAML

kubectl -n inject-demo wait --for=condition=Available deployment --all --timeout=300s

echo "inject-demo has three running workloads, no injection label, one container per pod."
