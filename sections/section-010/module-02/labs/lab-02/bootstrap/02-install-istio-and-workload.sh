#!/usr/bin/env bash
# Starting state for the removal lab: Istio 1.30.5 installed with Helm as three
# releases, an unrelated CRD that belongs to another team, and an injected
# workload in mesh-demo. The learner removes Istio; this script never does.
set -eu

ISTIO_VERSION="1.30.5"
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Installing Istio ${ISTIO_VERSION} with Helm..."
kubectl create namespace istio-system
kubectl create namespace istio-ingress

helm install istio-base istio/base -n istio-system \
  --version "$ISTIO_VERSION" --set defaultRevision=default --wait

cat > "$WORK/istiod-values.yaml" <<'YAML'
meshConfig:
  accessLogFile: /dev/stdout
pilot:
  autoscaleEnabled: false
YAML

helm install istiod istio/istiod -n istio-system \
  --version "$ISTIO_VERSION" -f "$WORK/istiod-values.yaml" --wait

helm install istio-ingressgateway istio/gateway -n istio-ingress \
  --version "$ISTIO_VERSION" --wait

echo "Adding a CRD that belongs to another team (it must survive the removal)..."
kubectl apply -f - <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backups.platform.example.com
spec:
  group: platform.example.com
  scope: Namespaced
  names:
    kind: Backup
    plural: backups
    singular: backup
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          x-kubernetes-preserve-unknown-fields: true
YAML

# helm returns once the Deployments report ready, a moment before the mutating
# webhook can inject: a pod created in that window comes back with no
# istio-proxy and nothing reports an error.
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

echo "Creating the injected workload in mesh-demo..."
kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: mesh-demo
  labels:
    istio-injection: enabled
---
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
YAML

kubectl -n mesh-demo rollout status deployment/notification-service --timeout=180s

# If the pod still slipped through without a sidecar, create it once more.
containers=$(kubectl -n mesh-demo get pod -l app=notification-service \
  -o jsonpath='{.items[0].spec.initContainers[*].name} {.items[0].spec.containers[*].name}')
if ! grep -qw istio-proxy <<<"$containers"; then
  kubectl -n mesh-demo rollout restart deployment/notification-service
  kubectl -n mesh-demo rollout status deployment/notification-service --timeout=180s
fi

echo "Istio is installed with Helm, and mesh-demo runs one injected workload."
