#!/usr/bin/env bash
# Confirms the canary upgrade: both control planes running, a prod revision tag
# resolving to 1-30-5, canary-demo following the tag rather than a raw revision
# label, and its workload restarted onto the new control plane.

set -u

REV="1-30-5"
TAG="prod"
NS="canary-demo"
DEPLOY="notification-service-v1"
WANT="1.30.5"

fail() { echo "FAIL: $*"; exit 1; }

# --- 1. the original control plane is still running -------------------------
old_ready=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$old_ready" || "$old_ready" -lt 1 ]]; then
  fail "istiod - the original control plane is gone or not ready. A canary upgrade leaves it running; that is what makes the rollback cheap"
fi

# --- 2. the canary control plane exists -------------------------------------
new_ready=$(kubectl -n istio-system get deployment "istiod-${REV}" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$new_ready" || "$new_ready" -lt 1 ]]; then
  fail "istiod-${REV} - revisioned control plane not found or not ready. Install it with 'istioctl-${WANT} install --set profile=minimal --set revision=${REV} -y'"
fi

new_image=$(kubectl -n istio-system get deployment "istiod-${REV}" \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
new_version="${new_image##*:}"
if [[ "$new_version" != "$WANT" ]]; then
  fail "istiod-${REV} is running '$new_image' - expected version $WANT. Install the revision with the istioctl-${WANT} binary"
fi

# --- 3. the canary used the minimal profile ---------------------------------
rev_gw=$(kubectl -n istio-system get deployments -o name 2>/dev/null | grep -- "-${REV}" | grep -i gateway || true)
if [[ -n "$rev_gw" ]]; then
  fail "the canary revision installed gateways ($rev_gw). Use the minimal profile for a canary control plane - a full profile puts two sets of gateways in contention"
fi

# --- 4. the revision tag exists and resolves to the revision ----------------
if ! kubectl get mutatingwebhookconfiguration "istio-revision-tag-${TAG}" >/dev/null 2>&1; then
  fail "istio-revision-tag-${TAG} - no webhook for a tag named '${TAG}'. Create it with 'istioctl-${WANT} tag set ${TAG} --revision ${REV} -y'"
fi

# --- 5. the namespace follows the TAG, not a raw revision -------------------
ns_rev=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
if [[ "$ns_rev" != "$TAG" ]]; then
  if [[ "$ns_rev" == "$REV" ]]; then
    fail "$NS carries istio.io/rev='$REV' - the raw revision label. The task asks for the tag: istio.io/rev=${TAG}, so the next upgrade is a tag move rather than a relabel of every namespace"
  fi
  fail "$NS - label istio.io/rev is '$ns_rev', expected '${TAG}'"
fi

ns_injection=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ -n "$ns_injection" ]]; then
  fail "$NS still carries istio-injection='$ns_injection' alongside istio.io/rev. They are mutually exclusive - istio-injection wins silently and the workload stays on the default control plane. Remove it"
fi

# --- 6. the workload was restarted onto the new control plane ---------------
if ! kubectl -n "$NS" get deployment "$DEPLOY" >/dev/null 2>&1; then
  fail "$DEPLOY - deployment not found in $NS. It should have been restarted, not replaced"
fi

count=$(kubectl -n "$NS" get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$count" -ne 1 ]]; then
  fail "$NS holds $count deployments, expected exactly 1"
fi

pod=$(kubectl -n "$NS" get pod -l app=notification-service \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -z "$pod" ]]; then
  fail "$DEPLOY - no running pod found in $NS"
fi

containers=$(kubectl -n "$NS" get pod "$pod" \
  -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
if ! grep -qw "istio-proxy" <<<"$containers"; then
  fail "$pod has containers [$containers] - no istio-proxy. Relabelling a namespace does not move a pod that already exists; restart the workload"
fi

dp_image=$(kubectl -n "$NS" get pod "$pod" \
  -o jsonpath='{.spec.initContainers[?(@.name=="istio-proxy")].image}{.spec.containers[?(@.name=="istio-proxy")].image}' 2>/dev/null)
dp_version="${dp_image##*:}"
if [[ "$dp_version" != "$WANT" ]]; then
  fail "$pod is running proxy image '$dp_image' - expected $WANT. The pod predates the move; restart the workload so it is re-injected by the canary control plane"
fi

pod_rev=$(kubectl -n "$NS" get pod "$pod" \
  -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
if [[ "$pod_rev" != "$REV" ]]; then
  fail "$pod reports istio.io/rev='$pod_rev', expected '$REV'. The tag did not resolve to the canary revision, or the pod was injected before the move"
fi

pod_ready=$(kubectl -n "$NS" get pod "$pod" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [[ "$pod_ready" != "True" ]]; then
  fail "$pod is not Ready"
fi

echo "PASS: both control planes running, tag '${TAG}' in place, ${NS} following the tag, and ${DEPLOY} re-injected by revision ${REV} on ${WANT}"
exit 0
