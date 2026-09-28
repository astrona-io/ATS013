#!/usr/bin/env bash
# Confirms a demo-profile control plane is live (istiod + BOTH gateways), that
# the CRDs and injection webhook exist, that mesh-demo is labelled for the
# default revision, that the pre-existing workload was recreated into the mesh,
# and that control plane and data plane run the same version.

set -u

NS="mesh-demo"
DEPLOY="notification-service"

fail() { echo "FAIL: $*"; exit 1; }

# --- 1. control plane ------------------------------------------------------
if ! kubectl get namespace istio-system >/dev/null 2>&1; then
  fail "istio-system namespace not found - the control plane was never installed"
fi

istiod_ready=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$istiod_ready" || "$istiod_ready" -lt 1 ]]; then
  fail "istiod - deployment not found or has no ready replicas"
fi

# --- 2. demo profile means BOTH gateways -----------------------------------
for gw in istio-ingressgateway istio-egressgateway; do
  gw_ready=$(kubectl -n istio-system get deployment "$gw" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ -z "$gw_ready" || "$gw_ready" -lt 1 ]]; then
    fail "$gw - not found or not ready. The demo profile installs both the ingress and the egress gateway; a default or minimal profile does not"
  fi
done

# --- 3. CRDs and the injection webhook -------------------------------------
crd_count=$(kubectl get crd -o name 2>/dev/null | grep -c 'networking\.istio\.io$')
if [[ "$crd_count" -lt 1 ]]; then
  fail "no networking.istio.io CRDs found - the base component was not installed"
fi

if ! kubectl get mutatingwebhookconfiguration istio-sidecar-injector >/dev/null 2>&1; then
  fail "istio-sidecar-injector - mutating webhook configuration not found"
fi

# --- 4. namespace opted in --------------------------------------------------
injection=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ "$injection" != "enabled" ]]; then
  fail "$NS - label istio-injection is '$injection', expected 'enabled'"
fi

# --- 5. the pre-existing workload was recreated into the mesh ---------------
if ! kubectl -n "$NS" get deployment "$DEPLOY" >/dev/null 2>&1; then
  fail "$DEPLOY - deployment not found in $NS. It should have been restarted, not replaced"
fi

ready=$(kubectl -n "$NS" get deployment "$DEPLOY" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$ready" || "$ready" -lt 1 ]]; then
  fail "$DEPLOY - no ready replicas"
fi

deploy_count=$(kubectl -n "$NS" get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$deploy_count" -ne 1 ]]; then
  fail "$NS holds $deploy_count deployments, expected exactly 1 - do not add a second workload"
fi

pod=$(kubectl -n "$NS" get pod -l app="$DEPLOY" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -z "$pod" ]]; then
  fail "$DEPLOY - no running pod found in $NS"
fi

containers=$(kubectl -n "$NS" get pod "$pod" \
  -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
if ! grep -qw "istio-proxy" <<<"$containers"; then
  fail "$pod has containers [$containers] - no istio-proxy. Labelling the namespace does not inject pods that already exist; the workload must be recreated"
fi
if ! grep -qw "$DEPLOY" <<<"$containers"; then
  fail "$pod has containers [$containers] - the application container '$DEPLOY' is missing"
fi

pod_ready=$(kubectl -n "$NS" get pod "$pod" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [[ "$pod_ready" != "True" ]]; then
  fail "$pod is not Ready"
fi

# --- 6. the Service is untouched -------------------------------------------
if ! kubectl -n "$NS" get service "$DEPLOY" >/dev/null 2>&1; then
  fail "$DEPLOY - service not found in $NS; it should have been left in place"
fi

# --- 7. control plane and data plane agree ---------------------------------
cp_image=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
cp_version="${cp_image##*:}"

dp_image=$(kubectl -n "$NS" get pod "$pod" \
  -o jsonpath='{.spec.initContainers[?(@.name=="istio-proxy")].image}{.spec.containers[?(@.name=="istio-proxy")].image}' 2>/dev/null)
dp_version="${dp_image##*:}"

if [[ -z "$cp_version" || -z "$dp_version" ]]; then
  fail "could not read control plane ('$cp_image') or data plane ('$dp_image') image"
fi
if [[ "$cp_version" != "$dp_version" ]]; then
  fail "version skew - control plane is $cp_version, the injected proxy is $dp_version. Restart the workload after upgrading or reinstalling"
fi

echo "PASS: demo-profile control plane installed, CRDs and webhook present, ${NS} labelled, ${DEPLOY} recreated into the mesh, control plane and data plane both on ${cp_version}"
exit 0
