#!/usr/bin/env bash
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
# away. Recovering it from the release is part of the exercise.
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

echo "Starting state - three releases at ${ISTIO_CURRENT}, revision 1 each:"
helm ls -A
echo "The values file used above no longer exists on disk. Recovering it is part of the task."
