#!/usr/bin/env bash
# OS prep for the "Upgrade And Reconfigure Istio With Helm" playground.
# Environment preparation only: install helm and istioctl, then install Istio
# 1.29.8 through the three charts with a non-default values file, and run one
# injected workload. The upgrade itself is the module's subject and is left
# to you.
set -euo pipefail

ISTIO_CURRENT="1.29.8"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "[playground] Downloading Istio ${ISTIO_CURRENT} (istioctl, for version checks)..."
(cd "$WORK" && curl -fsSL https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_CURRENT" sh -)
install -m 0755 "$WORK/istio-${ISTIO_CURRENT}/bin/istioctl" "$BIN_DIR/istioctl"

if ! command -v helm >/dev/null 2>&1; then
  echo "[playground] Installing helm 3..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | HELM_INSTALL_DIR="$BIN_DIR" USE_SUDO=false bash
fi

helm repo add istio https://istio-release.storage.googleapis.com/charts >/dev/null
helm repo update >/dev/null

kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace istio-ingress --dry-run=client -o yaml | kubectl apply -f -

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

echo "[playground] Installing Istio ${ISTIO_CURRENT} via Helm: base -> istiod -> gateway..."
helm install istio-base istio/base -n istio-system --version "$ISTIO_CURRENT" \
  --set defaultRevision=default --wait
helm install istiod istio/istiod -n istio-system --version "$ISTIO_CURRENT" \
  -f "$WORK/istiod-values.yaml" --wait
helm install istio-ingressgateway istio/gateway -n istio-ingress --version "$ISTIO_CURRENT" --wait

echo "[playground] Deploying one injected workload so the data plane is observable..."
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
kubectl -n default wait --for=condition=Available deployment/notification-service --timeout=300s

echo "[playground] Starting state — three releases at ${ISTIO_CURRENT}, revision 1 each:"
helm ls -A
echo "[playground] The values above live in the release, not on disk. Recreating that"
echo "[playground] values file before you upgrade is part of the exercise."
