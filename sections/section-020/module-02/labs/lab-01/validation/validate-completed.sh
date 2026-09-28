#!/usr/bin/env bash
# Confirms the injection matrix: namespace opted in, one workload meshed by the
# namespace, one excluded by a pod-template label, one forced in by a
# pod-template label - and that every override sits on the template, not on the
# Deployment.

set -u

NS="inject-demo"

fail() { echo "FAIL: $*"; exit 1; }

# running_pod <app-label> -> pod name
running_pod() {
  kubectl -n "$NS" get pod -l "app=$1" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# template_label <deployment> <label-key> -> value on spec.template.metadata.labels
template_label() {
  kubectl -n "$NS" get deployment "$1" \
    -o jsonpath="{.spec.template.metadata.labels.$2}" 2>/dev/null
}

# --- 1. the namespace opted in ----------------------------------------------
injection=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ "$injection" != "enabled" ]]; then
  fail "$NS - label istio-injection is '$injection', expected 'enabled'"
fi

rev=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
if [[ -n "$rev" ]]; then
  fail "$NS carries both istio-injection and istio.io/rev='$rev'. They are mutually exclusive - istio-injection wins silently and the revision label is ignored"
fi

# --- 2. all three Deployments survived --------------------------------------
count=$(kubectl -n "$NS" get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$count" -ne 3 ]]; then
  fail "$NS holds $count deployments, expected exactly 3 (notification-service, logging-agent, batch-job)"
fi

for d in notification-service logging-agent batch-job; do
  ready=$(kubectl -n "$NS" get deployment "$d" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ -z "$ready" || "$ready" -lt 1 ]]; then
    fail "$d - deployment not found in $NS or has no ready replicas"
  fi
done

# --- 3. notification-service: meshed by the namespace label -----------------
pod=$(running_pod notification-service)
[[ -n "$pod" ]] || fail "notification-service - no running pod found"
containers=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
if ! grep -qw "istio-proxy" <<<"$containers"; then
  fail "notification-service pod has containers [$containers] - no istio-proxy. Labelling the namespace does not inject pods that already exist; restart the workload"
fi

# --- 4. logging-agent: excluded, by a TEMPLATE label ------------------------
pod=$(running_pod logging-agent)
[[ -n "$pod" ]] || fail "logging-agent - no running pod found"
containers=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
if grep -qw "istio-proxy" <<<"$containers"; then
  fail "logging-agent pod has an istio-proxy sidecar - it must stay out of the mesh"
fi
n=$(wc -w <<<"$containers" | tr -d ' ')
if [[ "$n" -ne 1 ]]; then
  fail "logging-agent pod has $n containers [$containers], expected exactly 1"
fi

tpl=$(template_label logging-agent 'sidecar\.istio\.io/inject')
if [[ "$tpl" != "false" ]]; then
  dep=$(kubectl -n "$NS" get deployment logging-agent \
    -o jsonpath='{.metadata.labels.sidecar\.istio\.io/inject}' 2>/dev/null)
  if [[ -n "$dep" ]]; then
    fail "logging-agent has sidecar.istio.io/inject='$dep' on the Deployment's own metadata.labels. The webhook is registered against Pods and never sees the Deployment - move it to spec.template.metadata.labels"
  fi
  fail "logging-agent - spec.template.metadata.labels['sidecar.istio.io/inject'] is '$tpl', expected the string \"false\""
fi

# --- 5. batch-job: forced in, by a TEMPLATE label ---------------------------
pod=$(running_pod batch-job)
[[ -n "$pod" ]] || fail "batch-job - no running pod found"
containers=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
if ! grep -qw "istio-proxy" <<<"$containers"; then
  fail "batch-job pod has containers [$containers] - no istio-proxy"
fi

tpl=$(template_label batch-job 'sidecar\.istio\.io/inject')
if [[ "$tpl" != "true" ]]; then
  dep=$(kubectl -n "$NS" get deployment batch-job \
    -o jsonpath='{.metadata.labels.sidecar\.istio\.io/inject}' 2>/dev/null)
  if [[ -n "$dep" ]]; then
    fail "batch-job has sidecar.istio.io/inject='$dep' on the Deployment's own metadata.labels - move it to spec.template.metadata.labels"
  fi
  fail "batch-job - spec.template.metadata.labels['sidecar.istio.io/inject'] is '$tpl', expected the string \"true\". Its membership must not depend on the namespace label"
fi

echo "PASS: ${NS} opted in, notification-service meshed by the namespace, logging-agent excluded and batch-job forced in - both by pod-template labels"
exit 0
