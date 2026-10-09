#!/usr/bin/env bash
# Confirms Istio is fully removed: no istio-system namespace, no Istio CRDs,
# no Istio webhooks, no injection label on mesh-demo, and both mesh-demo
# workloads recreated without an istio-proxy sidecar and still serving traffic.
#
# Plausible but wrong fixes this grader rejects:
# - `istioctl uninstall` without `--purge` (or with `--revision default`):
#   the Istio CRDs stay, so check 2 fails.
# - Uninstalling and stopping there: istio-system, the namespace label and the
#   sidecars in the running pods all survive, so checks 1, 4 and 6 fail.
# - Getting rid of the sidecars by deleting the namespace or the workloads:
#   mesh-demo, both Deployments and the Service must still exist (check 5),
#   and the tester pod must still reach notification-service (check 7).

set -u

NS="mesh-demo"
SERVER="notification-service"
CLIENT="tester"

fail() { echo "FAIL: $*"; exit 1; }

# --- 1. the istio-system namespace is gone --------------------------------
if kubectl get namespace istio-system >/dev/null 2>&1; then
  phase=$(kubectl get namespace istio-system -o jsonpath='{.status.phase}' 2>/dev/null)
  if [[ "$phase" == "Terminating" ]]; then
    fail "istio-system is still Terminating - wait for the delete to finish, then submit again"
  fi
  fail "istio-system namespace still exists - istioctl uninstall does not delete it, delete it yourself"
fi

istiod_count=$(kubectl get deployments -A -l app=istiod -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$istiod_count" -ne 0 ]]; then
  fail "found $istiod_count istiod deployment(s) in the cluster - a control plane is still installed"
fi

# --- 2. no Istio CRDs remain ----------------------------------------------
crd_list=$(kubectl get crd -o name 2>/dev/null | grep -E '\.istio\.io$' || true)
if [[ -n "$crd_list" ]]; then
  crd_count=$(wc -l <<<"$crd_list" | tr -d ' ')
  fail "$crd_count Istio CRDs are still installed (for example $(head -1 <<<"$crd_list")). Only 'istioctl uninstall --purge' removes the CRDs"
fi

# --- 3. no Istio webhooks remain ------------------------------------------
webhooks=$(kubectl get mutatingwebhookconfigurations,validatingwebhookconfigurations \
  -o name 2>/dev/null | grep -i istio || true)
if [[ -n "$webhooks" ]]; then
  fail "Istio webhook configurations still exist: $(tr '\n' ' ' <<<"$webhooks")"
fi

# --- 4. the namespace no longer opts in to injection ----------------------
if ! kubectl get namespace "$NS" >/dev/null 2>&1; then
  fail "$NS namespace not found - it must stay; only its injection label goes"
fi

injection_label=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ -n "$injection_label" ]]; then
  fail "$NS still has the label istio-injection=$injection_label - remove the label, uninstall does not do it"
fi

revision_label=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
if [[ -n "$revision_label" ]]; then
  fail "$NS has the label istio.io/rev=$revision_label - remove it"
fi

# --- 5. the workloads were kept, not replaced -----------------------------
for deployment in "$SERVER" "$CLIENT"; do
  if ! kubectl -n "$NS" get deployment "$deployment" >/dev/null 2>&1; then
    fail "$deployment - deployment not found in $NS. Recreate its pods with a restart, do not delete it"
  fi
  ready=$(kubectl -n "$NS" get deployment "$deployment" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ -z "$ready" || "$ready" -lt 1 ]]; then
    fail "$deployment - no ready replicas"
  fi
done

deployment_count=$(kubectl -n "$NS" get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$deployment_count" -ne 2 ]]; then
  fail "$NS holds $deployment_count deployments, expected exactly 2 ($SERVER and $CLIENT)"
fi

if ! kubectl -n "$NS" get service "$SERVER" >/dev/null 2>&1; then
  fail "$SERVER - service not found in $NS; it should have been left in place"
fi

# --- 6. no pod in the namespace still carries a sidecar -------------------
pods_with_proxy=""
for pod in $(kubectl -n "$NS" get pods -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
  containers=$(kubectl -n "$NS" get pod "$pod" \
    -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
  if grep -qw "istio-proxy" <<<"$containers"; then
    pods_with_proxy="$pods_with_proxy $pod"
  fi
done
if [[ -n "$pods_with_proxy" ]]; then
  fail "these pods still have an istio-proxy container:$pods_with_proxy. Uninstall does not remove sidecars from running pods; recreate them (if an old pod is still terminating, wait and submit again)"
fi

# --- 7. traffic still works without the mesh -------------------------------
status_code=$(kubectl -n "$NS" exec "deploy/$CLIENT" -- \
  curl -s -o /dev/null -m 10 -w '%{http_code}' "http://$SERVER" 2>/dev/null)
if [[ "$status_code" != "200" ]]; then
  fail "a request from $CLIENT to http://$SERVER returned '$status_code', expected 200"
fi

echo "PASS: Istio fully removed (no istio-system, CRDs or webhooks), ${NS} unlabelled, ${SERVER} and ${CLIENT} recreated without sidecars, and ${CLIENT} gets a 200 from http://${SERVER}"
exit 0
