#!/usr/bin/env bash
# Confirms the in-place upgrade: one control plane replaced rather than
# canaried, the profile's ingress gateway kept, and every proxy in the mesh -
# gateway included - restarted onto the new version.

set -u

NS="inplace-demo"
WANT="1.30.5"

fail() { echo "FAIL: $*"; exit 1; }

# --- 1. exactly one control plane, at the new version -----------------------
istiod_deploys=$(kubectl -n istio-system get deployments -o name 2>/dev/null | grep -c 'deployment.apps/istiod')
if [[ "$istiod_deploys" -eq 0 ]]; then
  fail "no istiod deployment found in istio-system"
fi
if [[ "$istiod_deploys" -gt 1 ]]; then
  names=$(kubectl -n istio-system get deployments -o name 2>/dev/null | grep 'deployment.apps/istiod' | tr '\n' ' ')
  fail "found $istiod_deploys istiod deployments ($names) - this is a canary, not an in-place upgrade. An in-place upgrade reuses the same revision, so the object keeps its name"
fi

rev_webhook=$(kubectl get mutatingwebhookconfigurations -o name 2>/dev/null \
  | grep -E 'istio-sidecar-injector-.+' || true)
if [[ -n "$rev_webhook" ]]; then
  fail "a revisioned injection webhook exists ($rev_webhook) - a revision was installed. This task is an in-place upgrade"
fi

cp_image=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
cp_version="${cp_image##*:}"
if [[ "$cp_version" != "$WANT" ]]; then
  fail "istiod is running '$cp_image' - expected version $WANT. Upgrade with the istioctl-${WANT} binary"
fi

istiod_ready=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$istiod_ready" || "$istiod_ready" -lt 1 ]]; then
  fail "istiod - has no ready replicas after the upgrade"
fi

# --- 2. the profile's ingress gateway survived and was restarted ------------
gw_ready=$(kubectl -n istio-system get deployment istio-ingressgateway \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$gw_ready" || "$gw_ready" -lt 1 ]]; then
  fail "istio-ingressgateway - not found or not ready. The upgrade keeps the default profile, which includes the ingress gateway"
fi

# A gateway Deployment carries `image: auto`; the injector substitutes the real
# proxy image on the Pod. Reading the Deployment template always yields 'auto',
# so the running pod is the only place the version is visible.
gw_image=$(kubectl -n istio-system get pod -l app=istio-ingressgateway \
  -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null)
gw_version="${gw_image##*:}"
if [[ "$gw_version" != "$WANT" ]]; then
  fail "the ingress gateway proxy is on $gw_version, expected $WANT. Gateways are Envoy workloads with no namespace label driving them - restart them explicitly"
fi

# --- 3. the workloads survived ----------------------------------------------
count=$(kubectl -n "$NS" get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$count" -ne 2 ]]; then
  fail "$NS holds $count deployments, expected exactly 2 (notification-service-v1, tester)"
fi

replicas=$(kubectl -n "$NS" get deployment notification-service-v1 \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$replicas" || "$replicas" -lt 2 ]]; then
  fail "notification-service-v1 has $replicas ready replicas, expected 2"
fi

# --- 4. EVERY proxy in the namespace is on the new version ------------------
pods=$(kubectl -n "$NS" get pods --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
if [[ -z "$pods" ]]; then
  fail "no running pods found in $NS"
fi

stale=""
while read -r p; do
  [[ -n "$p" ]] || continue
  img=$(kubectl -n "$NS" get pod "$p" \
    -o jsonpath='{.spec.initContainers[?(@.name=="istio-proxy")].image}{.spec.containers[?(@.name=="istio-proxy")].image}' 2>/dev/null)
  if [[ -z "$img" ]]; then
    fail "$p has no istio-proxy container - every workload in $NS should be meshed"
  fi
  v="${img##*:}"
  if [[ "$v" != "$WANT" ]]; then
    stale="$stale $p($v)"
  fi
done <<<"$pods"

if [[ -n "$stale" ]]; then
  fail "version skew - the control plane is $cp_version but these proxies are older:$stale. Upgrading istiod does not touch running pods; restart every meshed workload"
fi

echo "PASS: one control plane replaced in place at ${WANT}, ingress gateway kept and restarted, and every proxy in ${NS} on ${WANT} - no skew"
exit 0
