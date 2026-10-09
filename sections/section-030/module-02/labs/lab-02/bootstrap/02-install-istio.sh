#!/usr/bin/env bash
# Starting state for "Retire The Old Control Plane Revision":
# - Istio 1.29.8 as the default (unrevisioned) control plane, demo profile.
# - Istio 1.30.5 as revision 1-30-5 (minimal profile), with the prod tag on it.
# - canary-demo already moved: labelled istio.io/rev=prod, workload injected by 1-30-5.
# - canary-legacy NOT moved: still istio-injection=enabled, tester injected by 1.29.8.
# Moving canary-legacy and uninstalling the default revision is the task.
set -eu

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
export PATH="$BIN_DIR:$PATH"

echo "Installing Istio 1.29.8 as the default revision..."
istioctl install --set profile=demo -y
kubectl -n istio-system wait --for=condition=Available deployment --all --timeout=300s

echo "Creating canary-legacy, injected by the default control plane..."
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: canary-legacy
  labels:
    istio-injection: enabled
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tester
  namespace: canary-legacy
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
kubectl -n canary-legacy wait --for=condition=Available deployment/tester --timeout=300s

echo "Installing Istio 1.30.5 as revision 1-30-5 and pointing the prod tag at it..."
istioctl-1.30.5 install --set profile=minimal --set revision=1-30-5 -y
kubectl -n istio-system wait --for=condition=Available deployment/istiod-1-30-5 --timeout=300s
istioctl-1.30.5 tag set prod --revision 1-30-5 -y

wait_for_tag_webhook() {
  local attempt
  for attempt in $(seq 1 90); do
    if kubectl get mutatingwebhookconfiguration istio-revision-tag-prod >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "istio-revision-tag-prod did not appear" >&2
  return 1
}
wait_for_tag_webhook

echo "Creating canary-demo, already following the prod tag..."
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: canary-demo
  labels:
    istio.io/rev: prod
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service-v1
  namespace: canary-demo
  labels:
    app: notification-service
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notification-service
      version: v1
  template:
    metadata:
      labels:
        app: notification-service
        version: v1
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
  namespace: canary-demo
spec:
  selector:
    app: notification-service
  ports:
    - name: http
      port: 80
      targetPort: 80
YAML
kubectl -n canary-demo rollout status deployment/notification-service-v1 --timeout=300s

echo "Starting state - two control planes:"
kubectl -n istio-system get pods -l app=istiod
