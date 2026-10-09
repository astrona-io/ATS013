#!/usr/bin/env bash
# Starting state for the "Remove Istio Completely" lab: a demo-profile control
# plane, the mesh-demo namespace labelled for injection, and two workloads
# (notification-service and tester) whose pods both carry an istio-proxy
# sidecar. This is the state the learner must clean up; it is never the
# graded end state.
set -eu

istioctl install --set profile=demo -y

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: mesh-demo
  labels:
    istio-injection: enabled
YAML

# istioctl returns once the Deployments report ready, a moment before the
# mutating webhook can inject. Pods created in that window get no sidecar.
wait_for_injector() {
  local attempt
  for attempt in $(seq 1 90); do
    if kubectl get mutatingwebhookconfiguration istio-sidecar-injector >/dev/null 2>&1; then
      if kubectl -n istio-system get endpoints istiod \
          -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | grep -q .; then
        return 0
      fi
    fi
    sleep 2
  done
  echo "the injection webhook did not become ready in time" >&2
  return 1
}
wait_for_injector

kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: mesh-demo
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
  namespace: mesh-demo
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
  namespace: mesh-demo
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
          image: curlimages/curl
          command: ["sleep", "infinity"]
YAML

for deployment in notification-service tester; do
  kubectl -n mesh-demo rollout status "deployment/${deployment}" --timeout=180s
done

# Make sure both pods really start with a sidecar; restart once if not.
for deployment in notification-service tester; do
  containers=$(kubectl -n mesh-demo get pod -l app="$deployment" \
    -o jsonpath='{.items[*].spec.initContainers[*].name} {.items[*].spec.containers[*].name}')
  if ! grep -qw istio-proxy <<<"$containers"; then
    kubectl -n mesh-demo rollout restart "deployment/${deployment}"
    kubectl -n mesh-demo rollout status "deployment/${deployment}" --timeout=180s
  fi
done

echo "Istio (demo profile) is installed and mesh-demo runs two injected workloads."
