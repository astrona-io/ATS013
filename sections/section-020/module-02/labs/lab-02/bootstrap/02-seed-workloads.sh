#!/usr/bin/env bash
# Starting state: inject-demo is labelled for injection and notification-service
# runs with an istio-proxy sidecar that captures every port. Excluding port 5432
# is the learner's task, so no traffic.sidecar.istio.io annotation is set here.
set -eu

# istiod reports Available a moment before the webhook can inject. A pod created
# in that window comes back with no istio-proxy and nothing reports an error.
wait_for_injector() {
  local attempt
  for attempt in $(seq 1 90); do
    if kubectl get mutatingwebhookconfiguration -o name 2>/dev/null | grep -q 'sidecar-injector'; then
      if kubectl -n istio-system get endpoints -o name 2>/dev/null | grep -q istiod; then
        return 0
      fi
    fi
    sleep 2
  done
}
wait_for_injector

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: inject-demo
  labels:
    istio-injection: enabled
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
apiVersion: v1
kind: Service
metadata:
  name: notification-service
  namespace: inject-demo
spec:
  selector:
    app: notification-service
  ports:
    - name: http
      port: 80
      targetPort: 80
YAML

kubectl -n inject-demo wait --for=condition=Available deployment/notification-service --timeout=300s

# If the pod still slipped through before the webhook was ready, create it again.
containers=$(kubectl -n inject-demo get pod -l app=notification-service \
  -o jsonpath='{.items[0].spec.initContainers[*].name} {.items[0].spec.containers[*].name}')
if ! grep -qw istio-proxy <<<"$containers"; then
  kubectl -n inject-demo rollout restart deployment notification-service
  kubectl -n inject-demo rollout status deployment notification-service --timeout=300s
fi

echo "inject-demo is injected; notification-service runs with an istio-proxy sidecar and no capture exclusions."
