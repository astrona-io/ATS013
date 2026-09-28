#!/usr/bin/env bash
# Section 030 capstone grader.
#
# Confirms a complete canary migration: the new revision installed and tagged,
# both namespaces moved through the tag, every proxy restarted onto the new
# version, and the old control plane retired - with the shared CRDs intact,
# proving --purge was not used.

set -u

REV="1-30-5"
TAG="prod"
WANT="1.30.5"

fail() { echo "FAIL: $*"; exit 1; }

# --- 1. the canary control plane is the only one left -----------------------
new_ready=$(kubectl -n istio-system get deployment "istiod-${REV}" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$new_ready" || "$new_ready" -lt 1 ]]; then
  fail "istiod-${REV} - revisioned control plane not found or not ready"
fi

new_image=$(kubectl -n istio-system get deployment "istiod-${REV}" \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
new_version="${new_image##*:}"
if [[ "$new_version" != "$WANT" ]]; then
  fail "istiod-${REV} is running '$new_image' - expected $WANT. Install the revision with the istioctl-${WANT} binary"
fi

if kubectl -n istio-system get deployment istiod >/dev/null 2>&1; then
  fail "the unrevisioned 'istiod' deployment is still present - the old control plane was never retired. Remove it with 'istioctl uninstall --revision default -y' AFTER every workload has moved"
fi

if kubectl get mutatingwebhookconfiguration istio-sidecar-injector >/dev/null 2>&1; then
  fail "the unrevisioned 'istio-sidecar-injector' webhook still exists - the default revision was not fully removed"
fi

# --- 2. --purge was not used: the shared CRDs survived ----------------------
crd_count=$(kubectl get crd -o name 2>/dev/null | grep -c 'networking\.istio\.io$')
if [[ "$crd_count" -lt 1 ]]; then
  fail "the networking.istio.io CRDs are gone - 'istioctl uninstall --purge' removes every revision and the shared cluster resources. Retire one revision by name instead"
fi

# --- 3. the tag exists ------------------------------------------------------
if ! kubectl get mutatingwebhookconfiguration "istio-revision-tag-${TAG}" >/dev/null 2>&1; then
  fail "istio-revision-tag-${TAG} - no webhook for a tag named '${TAG}'"
fi

# --- 4. both namespaces follow the tag --------------------------------------
for ns in payments orders; do
  ns_rev=$(kubectl get namespace "$ns" \
    -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
  if [[ "$ns_rev" != "$TAG" ]]; then
    if [[ "$ns_rev" == "$REV" ]]; then
      fail "$ns carries istio.io/rev='$REV' - the raw revision label. The specification asks for the tag, so the next upgrade is one tag move rather than a relabel of every namespace"
    fi
    fail "$ns - label istio.io/rev is '$ns_rev', expected '${TAG}'"
  fi

  ns_injection=$(kubectl get namespace "$ns" \
    -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
  if [[ -n "$ns_injection" ]]; then
    fail "$ns still carries istio-injection='$ns_injection' alongside istio.io/rev - they are mutually exclusive and istio-injection wins silently"
  fi
done

# --- 5. the workloads survived with their shapes ----------------------------
pay_count=$(kubectl -n payments get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$pay_count" -ne 1 ]]; then
  fail "payments holds $pay_count deployments, expected exactly 1 (checkout-api)"
fi
pay_replicas=$(kubectl -n payments get deployment checkout-api \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$pay_replicas" || "$pay_replicas" -lt 2 ]]; then
  fail "checkout-api has $pay_replicas ready replicas, expected 2"
fi

ord_count=$(kubectl -n orders get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$ord_count" -ne 2 ]]; then
  fail "orders holds $ord_count deployments, expected exactly 2 (order-api, tester)"
fi

# --- 6. EVERY meshed pod is on the new revision AND the new version ---------
stale=""
wrongrev=""
total=0
for ns in payments orders; do
  pods=$(kubectl -n "$ns" get pods --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
  while read -r p; do
    [[ -n "$p" ]] || continue
    total=$((total + 1))
    img=$(kubectl -n "$ns" get pod "$p" \
      -o jsonpath='{.spec.initContainers[?(@.name=="istio-proxy")].image}{.spec.containers[?(@.name=="istio-proxy")].image}' 2>/dev/null)
    if [[ -z "$img" ]]; then
      fail "$ns/$p has no istio-proxy container - every workload in both namespaces should be meshed"
    fi
    v="${img##*:}"
    [[ "$v" == "$WANT" ]] || stale="$stale $ns/$p($v)"

    r=$(kubectl -n "$ns" get pod "$p" \
      -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
    [[ "$r" == "$REV" ]] || wrongrev="$wrongrev $ns/$p(rev=$r)"
  done <<<"$pods"
done

if [[ "$total" -lt 4 ]]; then
  fail "found only $total running meshed pods across payments and orders, expected 4"
fi
if [[ -n "$stale" ]]; then
  fail "version skew - these proxies are not on $WANT:$stale. Relabelling a namespace does not move pods that already exist; restart every workload"
fi
if [[ -n "$wrongrev" ]]; then
  fail "these pods are not attached to revision $REV:$wrongrev. They were injected before the move, or the tag does not resolve to the canary revision"
fi

echo "PASS: revision ${REV} promoted behind tag '${TAG}', both namespaces migrated, all ${total} proxies on ${WANT}, old control plane retired by name with the shared CRDs intact"
exit 0
