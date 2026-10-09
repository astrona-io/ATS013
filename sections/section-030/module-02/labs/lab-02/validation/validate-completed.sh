#!/usr/bin/env bash
# Confirms the old revision was retired safely: the default control plane is
# gone, revision 1-30-5 and the shared CRDs are still there, canary-legacy now
# follows the prod tag, every proxy in both namespaces runs 1.30.5 from
# revision 1-30-5, and tester can still reach notification-service.
#
# Plausible wrong fixes this grader rejects:
# - `istioctl uninstall --purge`: removes istiod-1-30-5 and the CRDs too.
# - Removing istio-injection from canary-legacy without a revision label:
#   tester comes back with no sidecar, so it is no longer in the mesh.
# - Uninstalling before restarting tester: its pod keeps the 1.29.8 proxy.
# - Labelling canary-legacy with the raw revision instead of the tag.

set -u

REVISION="1-30-5"
TAG="prod"
WANT_VERSION="1.30.5"
LEGACY_NS="canary-legacy"
SERVICE_NS="canary-demo"
SERVICE_URL="http://notification-service.canary-demo"

fail() { echo "FAIL: $*"; exit 1; }

# Prints the revision that injected a pod: the annotation first, the label as fallback.
pod_revision() {
  local namespace="$1" pod="$2" revision
  revision=$(kubectl -n "$namespace" get pod "$pod" \
    -o jsonpath='{.metadata.annotations.istio\.io/rev}' 2>/dev/null)
  if [[ -z "$revision" ]]; then
    revision=$(kubectl -n "$namespace" get pod "$pod" \
      -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
  fi
  echo "$revision"
}

# Checks one running pod: it has istio-proxy, runs WANT_VERSION, was injected
# by REVISION and is Ready.
check_pod_on_new_revision() {
  local namespace="$1" app_label="$2" pod containers proxy_image proxy_version revision ready
  pod=$(kubectl -n "$namespace" get pod -l "app=${app_label}" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [[ -n "$pod" ]] || fail "no running pod with app=${app_label} in ${namespace}"

  containers=$(kubectl -n "$namespace" get pod "$pod" \
    -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
  if ! grep -qw "istio-proxy" <<<"$containers"; then
    fail "$namespace/$pod has no istio-proxy container. Label the namespace istio.io/rev=${TAG} before you restart, so the canary control plane injects the pod"
  fi

  proxy_image=$(kubectl -n "$namespace" get pod "$pod" \
    -o jsonpath='{.spec.initContainers[?(@.name=="istio-proxy")].image}{.spec.containers[?(@.name=="istio-proxy")].image}' 2>/dev/null)
  proxy_version="${proxy_image##*:}"
  if [[ "$proxy_version" != "$WANT_VERSION" ]]; then
    fail "$namespace/$pod runs proxy image '$proxy_image', expected $WANT_VERSION. The pod was not created again after the move"
  fi

  revision=$(pod_revision "$namespace" "$pod")
  if [[ "$revision" != "$REVISION" ]]; then
    fail "$namespace/$pod reports istio.io/rev='$revision', expected '$REVISION'"
  fi

  ready=$(kubectl -n "$namespace" get pod "$pod" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  [[ "$ready" == "True" ]] || fail "$namespace/$pod is not Ready"
}

# --- 1. the old control plane is gone ----------------------------------------
if kubectl -n istio-system get deployment istiod >/dev/null 2>&1; then
  fail "the default revision (Deployment istiod) is still installed. Retire it with 'istioctl uninstall --revision default -y' once every workload has moved"
fi

# --- 2. the new control plane and the shared CRDs are still there ------------
new_ready=$(kubectl -n istio-system get deployment "istiod-${REVISION}" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$new_ready" || "$new_ready" -lt 1 ]]; then
  fail "istiod-${REVISION} is gone or not ready. 'istioctl uninstall --purge' removes every revision; name the revision you want to remove"
fi

if ! kubectl get crd virtualservices.networking.istio.io >/dev/null 2>&1; then
  fail "the Istio CRDs are gone. Only --purge removes them; uninstall by revision name instead"
fi

if ! kubectl get mutatingwebhookconfiguration "istio-revision-tag-${TAG}" >/dev/null 2>&1; then
  fail "the '${TAG}' revision tag webhook is gone. Keep the tag pointing at revision ${REVISION}"
fi

# --- 3. no namespace is still labelled for the old control plane -------------
legacy_namespaces=$(kubectl get namespaces -l istio-injection=enabled -o name 2>/dev/null)
if [[ -n "$legacy_namespaces" ]]; then
  fail "namespaces still labelled istio-injection=enabled: ${legacy_namespaces}. They point at the removed control plane"
fi

legacy_rev=$(kubectl get namespace "$LEGACY_NS" \
  -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
if [[ "$legacy_rev" != "$TAG" ]]; then
  if [[ "$legacy_rev" == "$REVISION" ]]; then
    fail "$LEGACY_NS carries istio.io/rev='$REVISION', the raw revision label. The task asks for the tag: istio.io/rev=${TAG}"
  fi
  fail "$LEGACY_NS has istio.io/rev='$legacy_rev', expected '${TAG}'"
fi

# --- 4. both workloads run on the new revision -------------------------------
deployment_count=$(kubectl -n "$LEGACY_NS" get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
[[ "$deployment_count" -eq 1 ]] || fail "$LEGACY_NS holds $deployment_count Deployments, expected exactly 1 (tester). Restart it, do not replace it"
kubectl -n "$LEGACY_NS" get deployment tester >/dev/null 2>&1 \
  || fail "Deployment tester not found in $LEGACY_NS"

check_pod_on_new_revision "$LEGACY_NS" tester
check_pod_on_new_revision "$SERVICE_NS" notification-service

# --- 5. traffic still flows ---------------------------------------------------
status_code=""
for attempt in 1 2 3 4 5 6; do
  status_code=$(kubectl -n "$LEGACY_NS" exec deploy/tester -c tester -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$SERVICE_URL" 2>/dev/null)
  [[ "$status_code" == "200" ]] && break
  sleep 5
done
if [[ "$status_code" != "200" ]]; then
  fail "a request from tester to ${SERVICE_URL} returned '${status_code}', expected 200"
fi

echo "PASS: default revision retired, istiod-${REVISION} and the CRDs kept, ${LEGACY_NS} follows the '${TAG}' tag, every proxy runs ${WANT_VERSION}, and tester gets 200 from notification-service"
exit 0
