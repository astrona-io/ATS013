#!/usr/bin/env bash
# Confirms the customized install: the egress gateway removed while the ingress
# gateway survived, istiod resized, and both meshConfig settings live in the
# istio ConfigMap - with the meshed workload still running.

set -u

fail() { echo "FAIL: $*"; exit 1; }

# --- 1. control plane still healthy -----------------------------------------
istiod_ready=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$istiod_ready" || "$istiod_ready" -lt 1 ]]; then
  fail "istiod - deployment not found or has no ready replicas"
fi

# --- 2. components layer: egress gone, ingress kept -------------------------
egress=$(kubectl get deployments -A -o name 2>/dev/null | grep -i 'egressgateway' || true)
if [[ -n "$egress" ]]; then
  fail "an egress gateway is still running ($egress) - disable it through components.egressGateways"
fi

ingress_ready=$(kubectl -n istio-system get deployment istio-ingressgateway \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$ingress_ready" || "$ingress_ready" -lt 1 ]]; then
  fail "istio-ingressgateway - not found or not ready. The task removes only the egress gateway; installing the minimal profile removes both"
fi

# --- 3. components layer: istiod sizing -------------------------------------
cpu=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
if [[ "$cpu" != "100m" ]]; then
  fail "istiod requests cpu '$cpu', expected 100m from components.pilot.k8s.resources.requests.cpu"
fi

# --- 4. meshConfig layer: both settings live --------------------------------
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

# --- 5. the mesh still works ------------------------------------------------
injection=$(kubectl get namespace mesh-demo \
  -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ "$injection" != "enabled" ]]; then
  fail "mesh-demo - label istio-injection is '$injection', expected 'enabled'"
fi

pod=$(kubectl -n mesh-demo get pod -l app=notification-service \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -z "$pod" ]]; then
  fail "notification-service - no running pod found in mesh-demo"
fi

containers=$(kubectl -n mesh-demo get pod "$pod" \
  -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
if ! grep -qw "istio-proxy" <<<"$containers"; then
  fail "$pod has containers [$containers] - no istio-proxy. Reinstalling must not break the meshed workload"
fi

pod_ready=$(kubectl -n mesh-demo get pod "$pod" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [[ "$pod_ready" != "True" ]]; then
  fail "$pod is not Ready"
fi

echo "PASS: egress gateway removed, ingress gateway kept, istiod at 100m CPU, accessLogFile and REGISTRY_ONLY live in the mesh config, mesh-demo still meshed"
exit 0
