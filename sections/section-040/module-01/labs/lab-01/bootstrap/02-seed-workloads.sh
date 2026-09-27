#!/usr/bin/env bash
set -eu

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: ambient-demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: ambient-demo
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
  namespace: ambient-demo
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
  namespace: ambient-demo
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

kubectl -n ambient-demo wait --for=condition=Available deployment --all --timeout=300s

# Record every pod UID. Enrollment in ambient mode must not recreate any pod,
# and comparing UIDs afterwards is how the grader proves it.
uids=$(kubectl -n ambient-demo get pods \
  -o jsonpath='{range .items[*]}{.metadata.name}={.metadata.uid}{"\n"}{end}' | sort)
kubectl -n ambient-demo create configmap lab-baseline \
  --from-literal=pod-uids="$uids" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Baseline pod UIDs recorded in configmap ambient-demo/lab-baseline:"
echo "$uids"
echo "ambient-demo is NOT enrolled and every pod has exactly one container."
