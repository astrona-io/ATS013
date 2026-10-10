#!/usr/bin/env bash
# Confirms that notification-service keeps its sidecar proxy while outbound port
# 5432 (and nothing else) is excluded from traffic capture, set on the pod
# template and visible in the istio-init rules of the running pod.
#
# Plausible wrong fixes this grader rejects:
#   - turning injection off for the workload (sidecar.istio.io/inject: "false"),
#     which takes every port out of the mesh, not just 5432
#   - putting the annotation on the Deployment's own metadata.annotations,
#     which applies cleanly and changes nothing in the pod
#   - excluding more than asked (other ports, or whole address ranges with
#     excludeOutboundIPRanges / includeOutboundIPRanges)

set -u

NAMESPACE="inject-demo"
DEPLOYMENT="notification-service"
EXPECTED_PORTS="5432"

fail() { echo "FAIL: $*"; exit 1; }

# template_annotation <key> -> value on spec.template.metadata.annotations
template_annotation() {
  kubectl -n "$NAMESPACE" get deployment "$DEPLOYMENT" \
    -o jsonpath="{.spec.template.metadata.annotations.$1}" 2>/dev/null
}

# init_arg_value <pod> <flag> -> the argument that follows <flag> in istio-init
init_arg_value() {
  kubectl -n "$NAMESPACE" get pod "$1" \
    -o jsonpath='{range .spec.initContainers[?(@.name=="istio-init")].args[*]}{@}{"\n"}{end}' 2>/dev/null \
    | awk -v flag="$2" 'found { print; exit } $0 == flag { found = 1 }'
}

# --- 1. the namespace is still injected and the workload survived ----------
injection_label=$(kubectl get namespace "$NAMESPACE" \
  -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ "$injection_label" != "enabled" ]]; then
  fail "$NAMESPACE - label istio-injection is '$injection_label', expected 'enabled'. Keep the namespace in the mesh"
fi

deployment_count=$(kubectl -n "$NAMESPACE" get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$deployment_count" -ne 1 ]]; then
  fail "$NAMESPACE holds $deployment_count deployments, expected exactly 1 ($DEPLOYMENT)"
fi

ready_replicas=$(kubectl -n "$NAMESPACE" get deployment "$DEPLOYMENT" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$ready_replicas" || "$ready_replicas" -lt 1 ]]; then
  fail "$DEPLOYMENT - deployment not found in $NAMESPACE or has no ready replicas"
fi

# --- 2. the workload is still in the mesh -----------------------------------
inject_label=$(kubectl -n "$NAMESPACE" get deployment "$DEPLOYMENT" \
  -o jsonpath='{.spec.template.metadata.labels.sidecar\.istio\.io/inject}' 2>/dev/null)
if [[ "$inject_label" == "false" ]]; then
  fail "$DEPLOYMENT has sidecar.istio.io/inject='false' on its pod template. That takes every port out of the mesh; exclude only port 5432 and keep the sidecar"
fi

# --- 3. the annotation is on the pod template, with exactly port 5432 -------
excluded_ports=$(template_annotation 'traffic\.sidecar\.istio\.io/excludeOutboundPorts')
if [[ "$excluded_ports" != "$EXPECTED_PORTS" ]]; then
  deployment_annotation=$(kubectl -n "$NAMESPACE" get deployment "$DEPLOYMENT" \
    -o jsonpath='{.metadata.annotations.traffic\.sidecar\.istio\.io/excludeOutboundPorts}' 2>/dev/null)
  if [[ -z "$excluded_ports" && -n "$deployment_annotation" ]]; then
    fail "$DEPLOYMENT has traffic.sidecar.istio.io/excludeOutboundPorts on the Deployment's own metadata.annotations. Injection only sees the pod - move it to spec.template.metadata.annotations"
  fi
  fail "$DEPLOYMENT - spec.template.metadata.annotations['traffic.sidecar.istio.io/excludeOutboundPorts'] is '$excluded_ports', expected exactly '$EXPECTED_PORTS'"
fi

for range_annotation in excludeOutboundIPRanges includeOutboundIPRanges excludeInboundPorts; do
  range_value=$(template_annotation "traffic\.sidecar\.istio\.io/$range_annotation")
  if [[ -n "$range_value" ]]; then
    fail "$DEPLOYMENT also sets traffic.sidecar.istio.io/$range_annotation='$range_value'. Only outbound port 5432 may leave the mesh"
  fi
done

# --- 4. every live pod has the sidecar and the exclusion in its rules -------
checked_pods=0
for pod_name in $(kubectl -n "$NAMESPACE" get pod -l "app=$DEPLOYMENT" \
    --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
  deletion=$(kubectl -n "$NAMESPACE" get pod "$pod_name" \
    -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null)
  [[ -z "$deletion" ]] || continue

  containers=$(kubectl -n "$NAMESPACE" get pod "$pod_name" \
    -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
  if ! grep -qw "istio-proxy" <<<"$containers"; then
    fail "pod $pod_name has containers [$containers] - no istio-proxy. The workload must stay in the mesh"
  fi

  pod_ready=$(kubectl -n "$NAMESPACE" get pod "$pod_name" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  if [[ "$pod_ready" != "True" ]]; then
    fail "pod $pod_name is not Ready yet - wait for the rollout to finish and submit again"
  fi

  outbound_exclusion=$(init_arg_value "$pod_name" "-o")
  if [[ "$outbound_exclusion" != "$EXPECTED_PORTS" ]]; then
    fail "pod $pod_name - istio-init has '-o $outbound_exclusion', expected '-o $EXPECTED_PORTS'. The pod must be created after the annotation is set"
  fi

  checked_pods=$((checked_pods + 1))
done

if [[ "$checked_pods" -lt 1 ]]; then
  fail "$DEPLOYMENT - no running pod found in $NAMESPACE"
fi

echo "PASS: $DEPLOYMENT keeps its istio-proxy sidecar, and only outbound port $EXPECTED_PORTS is excluded from capture through the pod template"
exit 0
