#!/usr/bin/env bash
# Confirms Istio was removed completely from a cluster where it was installed
# with Helm: the three releases and their cluster-wide objects are gone, only
# the Istio CRDs were deleted, the Istio namespaces are gone, and the workload
# in mesh-demo runs again from its original Deployment without a sidecar.
#
# Plausible wrong fixes this grader rejects:
#   - deleting the namespaces instead of running helm uninstall: the release
#     Secrets go, but the webhook configurations and cluster roles stay;
#   - running helm uninstall and stopping: the Istio CRDs stay;
#   - `kubectl delete crd --all`: the other team's CRD is deleted too;
#   - removing the namespace label and stopping: the running pod keeps its
#     istio-proxy container;
#   - deleting the Deployment and creating a new one instead of restarting it.
#
# Every check uses kubectl, so the grader does not depend on the helm binary.

set -u

NS="mesh-demo"
DEPLOY="notification-service"
OTHER_CRD="backups.platform.example.com"

fail() { echo "FAIL: $*"; exit 1; }

# --- 1. no Helm release record for any of the three releases ---------------
for release in istio-base istiod istio-ingressgateway; do
  records=$(kubectl get secret -A -l "owner=helm,name=$release" -o name 2>/dev/null)
  if [[ -n "$records" ]]; then
    fail "$release - a Helm release record still exists. Remove it with 'helm uninstall'"
  fi
done

# --- 2. no Istio control plane objects left in the cluster ------------------
istiod_deployments=$(kubectl get deployments -A -o name 2>/dev/null | grep -E 'istiod|istio-ingressgateway' || true)
if [[ -n "$istiod_deployments" ]]; then
  fail "Istio Deployments still exist: $istiod_deployments"
fi

mutating_webhooks=$(kubectl get mutatingwebhookconfigurations -o name 2>/dev/null | grep -i istio || true)
if [[ -n "$mutating_webhooks" ]]; then
  fail "Istio mutating webhook configurations still exist: $mutating_webhooks. Deleting the namespaces does not remove cluster-wide objects; use helm uninstall"
fi

validating_webhooks=$(kubectl get validatingwebhookconfigurations -o name 2>/dev/null | grep -i istio || true)
if [[ -n "$validating_webhooks" ]]; then
  fail "Istio validating webhook configurations still exist: $validating_webhooks. Use helm uninstall"
fi

istio_cluster_roles=$(kubectl get clusterroles -o name 2>/dev/null | grep -i istio || true)
if [[ -n "$istio_cluster_roles" ]]; then
  fail "Istio cluster roles still exist: $istio_cluster_roles. Use helm uninstall"
fi

# --- 3. only the Istio CRDs were deleted -------------------------------------
istio_crd_count=$(kubectl get crd -o name 2>/dev/null | grep -c 'istio\.io$')
if [[ "$istio_crd_count" -ne 0 ]]; then
  fail "$istio_crd_count Istio CRDs are still installed. helm uninstall leaves them in place; delete them yourself"
fi

if ! kubectl get crd "$OTHER_CRD" >/dev/null 2>&1; then
  fail "the CRD $OTHER_CRD is gone - it belongs to another team. Delete only the CRDs whose names end in istio.io"
fi

# --- 4. the Istio namespaces are gone ---------------------------------------
for namespace in istio-system istio-ingress; do
  if kubectl get namespace "$namespace" >/dev/null 2>&1; then
    fail "namespace $namespace still exists"
  fi
done

# --- 5. mesh-demo no longer opts in to injection -----------------------------
injection_label=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ -n "$injection_label" ]]; then
  fail "$NS still carries istio-injection=$injection_label - remove the label"
fi
revision_label=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
if [[ -n "$revision_label" ]]; then
  fail "$NS carries istio.io/rev=$revision_label - remove the label"
fi

# --- 6. the original workload runs again without a sidecar ------------------
if ! kubectl -n "$NS" get service "$DEPLOY" >/dev/null 2>&1; then
  fail "$DEPLOY - service not found in $NS; it should have been left in place"
fi

deploy_count=$(kubectl -n "$NS" get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$deploy_count" -ne 1 ]]; then
  fail "$NS holds $deploy_count deployments, expected exactly 1 - restart the existing one, do not replace it"
fi

# A pod that is still terminating has a deletionTimestamp; skip it.
live_pods=$(kubectl -n "$NS" get pods -l app="$DEPLOY" \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
  | awk 'NF==1 {print $1}')
if [[ -z "$live_pods" ]]; then
  fail "$DEPLOY - no pod found in $NS"
fi

for pod in $live_pods; do
  containers=$(kubectl -n "$NS" get pod "$pod" \
    -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
  if grep -qw "istio-proxy" <<<"$containers"; then
    fail "$pod still runs istio-proxy [$containers]. Running pods keep their sidecar until they are created again; restart the workload after removing the label"
  fi
  pod_ready=$(kubectl -n "$NS" get pod "$pod" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  if [[ "$pod_ready" != "True" ]]; then
    fail "$pod is not Ready"
  fi
done

echo "PASS: Helm releases and cluster-wide Istio objects removed, only the Istio CRDs deleted, Istio namespaces gone, ${DEPLOY} running without a sidecar"
exit 0
