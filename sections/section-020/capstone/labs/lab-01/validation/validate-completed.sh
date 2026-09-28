#!/usr/bin/env bash
# Section 020 capstone grader.
#
# Confirms the customized install across three IstioOperator layers, and the
# full injection matrix: payments opted in with one workload meshed and one
# excluded by a pod-template label, and legacy left entirely out of the mesh.

set -u

fail() { echo "FAIL: $*"; exit 1; }

running_pod() {
  kubectl -n "$1" get pod -l "app=$2" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# --- 1. control plane healthy -----------------------------------------------
istiod_ready=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$istiod_ready" || "$istiod_ready" -lt 1 ]]; then
  fail "istiod - deployment not found or has no ready replicas"
fi

# --- 2. components layer: egress gone, ingress kept, istiod resized ---------
egress=$(kubectl get deployments -A -o name 2>/dev/null | grep -i 'egressgateway' || true)
if [[ -n "$egress" ]]; then
  fail "an egress gateway is still running ($egress) - disable it through components.egressGateways"
fi

ingress_ready=$(kubectl -n istio-system get deployment istio-ingressgateway \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$ingress_ready" || "$ingress_ready" -lt 1 ]]; then
  fail "istio-ingressgateway - not found or not ready. Only the egress gateway is to be removed"
fi

cpu=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
mem=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
if [[ "$cpu" != "250m" ]]; then
  fail "istiod requests cpu '$cpu', expected 250m from components.pilot.k8s.resources.requests.cpu"
fi
if [[ "$mem" != "512Mi" ]]; then
  fail "istiod requests memory '$mem', expected 512Mi from components.pilot.k8s.resources.requests.memory"
fi

# --- 3. meshConfig layer ----------------------------------------------------
mesh=$(kubectl -n istio-system get configmap istio -o jsonpath='{.data.mesh}' 2>/dev/null)
if [[ -z "$mesh" ]]; then
  fail "the 'istio' ConfigMap in istio-system has no 'mesh' key"
fi
if ! grep -qE '^accessLogFile:[[:space:]]*/dev/stdout[[:space:]]*$' <<<"$mesh"; then
  fail "meshConfig.accessLogFile is not /dev/stdout in the live mesh config"
fi
if ! grep -qE 'mode:[[:space:]]*REGISTRY_ONLY' <<<"$mesh"; then
  fail "meshConfig.outboundTrafficPolicy.mode is not REGISTRY_ONLY in the live mesh config"
fi

# --- 4. payments opted in, exactly two deployments --------------------------
injection=$(kubectl get namespace payments \
  -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ "$injection" != "enabled" ]]; then
  fail "payments - label istio-injection is '$injection', expected 'enabled'"
fi

pay_count=$(kubectl -n payments get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$pay_count" -ne 2 ]]; then
  fail "payments holds $pay_count deployments, expected exactly 2 (checkout-api, audit-shipper)"
fi

if ! kubectl -n payments get service checkout-api >/dev/null 2>&1; then
  fail "checkout-api - service not found in payments; it should have been left in place"
fi

# --- 5. checkout-api meshed, with the values-layer proxy request ------------
pod=$(running_pod payments checkout-api)
[[ -n "$pod" ]] || fail "checkout-api - no running pod found in payments"

containers=$(kubectl -n payments get pod "$pod" -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
if ! grep -qw "istio-proxy" <<<"$containers"; then
  fail "checkout-api pod has containers [$containers] - no istio-proxy. Labelling the namespace does not inject a pod that already exists; restart the workload"
fi

proxy_cpu=$(kubectl -n payments get pod "$pod" \
  -o jsonpath='{.spec.initContainers[?(@.name=="istio-proxy")].resources.requests.cpu}{.spec.containers[?(@.name=="istio-proxy")].resources.requests.cpu}' 2>/dev/null)
if [[ "$proxy_cpu" != "20m" ]]; then
  fail "the injected sidecar requests cpu '$proxy_cpu', expected 20m. Sidecar defaults come from values.global.proxy.resources - a different layer from components.pilot, which sizes istiod itself"
fi

# --- 6. audit-shipper excluded, by a TEMPLATE label -------------------------
pod=$(running_pod payments audit-shipper)
[[ -n "$pod" ]] || fail "audit-shipper - no running pod found in payments"

containers=$(kubectl -n payments get pod "$pod" -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
if grep -qw "istio-proxy" <<<"$containers"; then
  fail "audit-shipper pod has an istio-proxy sidecar - it must stay out of the mesh"
fi
n=$(wc -w <<<"$containers" | tr -d ' ')
if [[ "$n" -ne 1 ]]; then
  fail "audit-shipper pod has $n containers [$containers], expected exactly 1"
fi

tpl=$(kubectl -n payments get deployment audit-shipper \
  -o jsonpath='{.spec.template.metadata.labels.sidecar\.istio\.io/inject}' 2>/dev/null)
if [[ "$tpl" != "false" ]]; then
  dep=$(kubectl -n payments get deployment audit-shipper \
    -o jsonpath='{.metadata.labels.sidecar\.istio\.io/inject}' 2>/dev/null)
  if [[ -n "$dep" ]]; then
    fail "audit-shipper has sidecar.istio.io/inject='$dep' on the Deployment's own metadata.labels. The webhook is registered against Pods and never sees the Deployment - move it to spec.template.metadata.labels"
  fi
  fail "audit-shipper - spec.template.metadata.labels['sidecar.istio.io/inject'] is '$tpl', expected the string \"false\""
fi

# --- 7. legacy entirely outside the mesh ------------------------------------
for key in istio-injection 'istio\.io/rev' 'istio\.io/dataplane-mode'; do
  v=$(kubectl get namespace legacy -o jsonpath="{.metadata.labels.$key}" 2>/dev/null)
  if [[ -n "$v" ]]; then
    fail "legacy carries a mesh label ($key='$v') - this namespace must stay entirely out of the mesh"
  fi
done

pod=$(running_pod legacy nightly-report)
[[ -n "$pod" ]] || fail "nightly-report - no running pod found in legacy; it should have been left alone"

containers=$(kubectl -n legacy get pod "$pod" -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
if grep -qw "istio-proxy" <<<"$containers"; then
  fail "nightly-report pod has an istio-proxy sidecar - legacy must stay out of the mesh"
fi
n=$(wc -w <<<"$containers" | tr -d ' ')
if [[ "$n" -ne 1 ]]; then
  fail "nightly-report pod has $n containers [$containers], expected exactly 1"
fi

# --- 8. everything still Available ------------------------------------------
for entry in "payments checkout-api" "payments audit-shipper" "legacy nightly-report"; do
  set -- $entry
  ready=$(kubectl -n "$1" get deployment "$2" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ -z "$ready" || "$ready" -lt 1 ]]; then
    fail "$2 in $1 - not found or has no ready replicas"
  fi
done

echo "PASS: egress removed and ingress kept, istiod at 250m/512Mi, accessLogFile and REGISTRY_ONLY live, sidecars default to 20m, checkout-api meshed, audit-shipper excluded by pod-template label, legacy untouched"
exit 0
