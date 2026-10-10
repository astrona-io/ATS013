#!/usr/bin/env bash
# Starting state: Istio 1.29.8 installed with Helm from a values file that is
# thrown away, then a bad `helm upgrade` of istiod with --reset-values
# (revision 2) that resets every setting to the chart defaults. A plain
# `helm upgrade` with no values would reuse the old values, so the flag is
# needed to create the fault. The workload is restarted
# after the bad upgrade, so its sidecar also carries the chart-default resource
# requests. Undoing this is the task; this script never applies the end state.
set -eu

ISTIO_CURRENT="1.29.8"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
export PATH="$BIN_DIR:$PATH"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace istio-ingress --dry-run=client -o yaml | kubectl apply -f -

# This values file is deliberately written to a temporary directory and thrown
# away. Only revision 1 of the release still holds it.
cat > "$WORK/istiod-values.yaml" <<'YAML'
meshConfig:
  accessLogFile: /dev/stdout
  outboundTrafficPolicy:
    mode: ALLOW_ANY
pilot:
  autoscaleEnabled: false
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
global:
  proxy:
    resources:
      requests:
        cpu: 10m
        memory: 64Mi
YAML

echo "Installing Istio ${ISTIO_CURRENT} via Helm: base -> istiod -> gateway..."
helm install istio-base istio/base -n istio-system --version "$ISTIO_CURRENT" \
  --set defaultRevision=default --wait
helm install istiod istio/istiod -n istio-system --version "$ISTIO_CURRENT" \
  -f "$WORK/istiod-values.yaml" --wait
helm install istio-ingressgateway istio/gateway -n istio-ingress --version "$ISTIO_CURRENT" --wait

kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: default
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
YAML
kubectl -n default rollout status deployment/notification-service --timeout=300s

echo "Running a helm upgrade of istiod with --reset-values (the bad change)..."
helm upgrade istiod istio/istiod -n istio-system --version "$ISTIO_CURRENT" --reset-values --wait

# helm returns once istiod reports ready, a moment before the webhook can
# inject: a pod recreated in that window comes back with no istio-proxy.
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

kubectl -n default rollout restart deployment notification-service
kubectl -n default rollout status deployment notification-service --timeout=300s

echo "Starting state - istiod at revision 2 with no user-supplied values:"
helm history istiod -n istio-system
