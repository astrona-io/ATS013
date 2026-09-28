#!/usr/bin/env bash
# Section 040 capstone grader.
#
# Confirms ambient enrollment with no pod recreated, a programmed and enrolled
# waypoint, an HTTPRoute proving L7 is in the path, and an L7 AuthorizationPolicy
# enforced on live traffic: GET allowed, DELETE denied.

set -u

NS="ambient-shop"
WP="waypoint"
ROUTE="catalog-header"
POLICY="catalog-methods"

fail() { echo "FAIL: $*"; exit 1; }

if ! command -v istioctl >/dev/null 2>&1; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# curl_from <deployment> <method> -> HTTP status code
curl_from() {
  kubectl -n "$NS" exec "deploy/$1" -c "$1" -- \
    curl -s -o /dev/null -m 10 -w '%{http_code}' -X "$2" http://catalog-api/ 2>/dev/null || echo "000"
}

# --- 1. enrolled in ambient mode, no sidecars -------------------------------
mode=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}' 2>/dev/null)
if [[ "$mode" != "ambient" ]]; then
  fail "$NS - label istio.io/dataplane-mode is '$mode', expected 'ambient'"
fi

injection=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ -n "$injection" ]]; then
  fail "$NS carries istio-injection='$injection' - a namespace is one mode or the other, never both"
fi

# --- 2. nothing was recreated -----------------------------------------------
baseline=$(kubectl -n "$NS" get configmap lab-baseline \
  -o jsonpath='{.data.pod-uids}' 2>/dev/null)
if [[ -z "$baseline" ]]; then
  fail "configmap $NS/lab-baseline is missing or empty - it records the pod UIDs from before enrollment and must be left in place"
fi

current=$(kubectl -n "$NS" get pods -l 'gateway.networking.k8s.io/gateway-name!=waypoint' \
  -o jsonpath='{range .items[*]}{.metadata.name}={.metadata.uid}{"\n"}{end}' 2>/dev/null | sort)

if [[ "$baseline" != "$current" ]]; then
  echo "--- application pods recorded before enrollment ---"
  echo "$baseline"
  echo "--- application pods running now ---"
  echo "$current"
  fail "the application pods are not the ones that were running before enrollment. Ambient enrollment changes node-level redirection and ztunnel state, not the pod - no restart is needed and none should have happened"
fi

while read -r line; do
  [[ -n "$line" ]] || continue
  pod="${line%%=*}"
  containers=$(kubectl -n "$NS" get pod "$pod" \
    -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
  if grep -qw "istio-proxy" <<<"$containers"; then
    fail "$pod has an istio-proxy sidecar - ambient mode never modifies the pod"
  fi
  n=$(wc -w <<<"$containers" | tr -d ' ')
  if [[ "$n" -ne 1 ]]; then
    fail "$pod has $n containers [$containers], expected exactly 1"
  fi
done <<<"$current"

# --- 3. the waypoint --------------------------------------------------------
class=$(kubectl -n "$NS" get gateway "$WP" \
  -o jsonpath='{.spec.gatewayClassName}' 2>/dev/null)
if [[ -z "$class" ]]; then
  fail "no Gateway named '$WP' in $NS. Create it with 'istioctl waypoint apply -n $NS --enroll-namespace'"
fi
if [[ "$class" != "istio-waypoint" ]]; then
  fail "Gateway $WP has gatewayClassName '$class', expected 'istio-waypoint'"
fi

programmed=$(kubectl -n "$NS" get gateway "$WP" \
  -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
if [[ "$programmed" != "True" ]]; then
  fail "Gateway $WP reports Programmed='$programmed', expected True"
fi

wp_ready=$(kubectl -n "$NS" get deployment "$WP" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$wp_ready" || "$wp_ready" -lt 1 ]]; then
  fail "the $WP deployment in $NS is not ready"
fi

use=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)
if [[ "$use" != "$WP" ]]; then
  fail "$NS - label istio.io/use-waypoint is '$use', expected '$WP'. Creating the waypoint is not enough; enroll the namespace to it"
fi

zt=$(istioctl ztunnel-config workload 2>/dev/null | awk -v ns="$NS" '$1 == ns' || true)
app_line=$(grep -E "[[:space:]]catalog-api-" <<<"$zt" | head -1)
if [[ -z "$app_line" ]]; then
  fail "ztunnel does not report a workload for catalog-api in $NS"
fi

# A waypoint attached to the Service shows in ztunnel's SERVICE view; the
# workload view's WAYPOINT column stays None for one, which says nothing about
# whether the waypoint is in the path.
svc_line=$(istioctl ztunnel-config service 2>/dev/null \
  | awk -v ns="$NS" '$1 == ns && $2 == "catalog-api"')
if [[ -z "$svc_line" ]]; then
  fail "ztunnel does not report the catalog-api Service in $NS"
fi
if ! grep -qw "$WP" <<<"$svc_line"; then
  fail "ztunnel does not route the catalog-api Service through the waypoint: $svc_line"
fi

# --- 4. the HTTPRoute -------------------------------------------------------
if ! kubectl -n "$NS" get httproute "$ROUTE" >/dev/null 2>&1; then
  fail "HTTPRoute '$ROUTE' not found in $NS"
fi
parent_kind=$(kubectl -n "$NS" get httproute "$ROUTE" \
  -o jsonpath='{.spec.parentRefs[0].kind}' 2>/dev/null)
parent_name=$(kubectl -n "$NS" get httproute "$ROUTE" \
  -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null)
if [[ "$parent_kind" != "Service" || "$parent_name" != "catalog-api" ]]; then
  fail "HTTPRoute $ROUTE attaches to ${parent_kind}/${parent_name}; expected Service/catalog-api"
fi

# --- 5. the AuthorizationPolicy exists --------------------------------------
if ! kubectl -n "$NS" get authorizationpolicy "$POLICY" >/dev/null 2>&1; then
  fail "AuthorizationPolicy '$POLICY' not found in $NS"
fi

# --- 6. LIVE behaviour: the header, then GET allowed and DELETE denied ------
# Only these checks prove anything is parsing HTTP. Object status says healthy
# with or without a waypoint in the path.
resp=""
for _ in 1 2 3 4 5 6; do
  resp=$(kubectl -n "$NS" exec deploy/storefront -c storefront -- \
    curl -s -i -m 10 http://catalog-api/ 2>/dev/null || true)
  grep -qi 'x-served-via' <<<"$resp" && break
  sleep 5
done

hdr=$(grep -i 'x-served-via' <<<"$resp" | tr -d '\r' || true)
if [[ -z "$hdr" ]]; then
  fail "the response carries no x-served-via header. The HTTPRoute exists, but nothing in the path is parsing HTTP - check the waypoint is running and the namespace is enrolled to it"
fi
if ! grep -qi 'x-served-via:[[:space:]]*waypoint' <<<"$hdr"; then
  fail "the response header is '$hdr', expected 'x-served-via: waypoint'"
fi

get_code=""
for _ in 1 2 3 4 5 6; do
  get_code=$(curl_from storefront GET)
  [[ "$get_code" == "200" ]] && break
  sleep 5
done
if [[ "$get_code" != "200" ]]; then
  fail "a GET from storefront to catalog-api returned $get_code, expected 200. The policy must allow GET"
fi

del_code=""
for _ in 1 2 3 4 5 6; do
  del_code=$(curl_from storefront DELETE)
  [[ "$del_code" == "403" ]] && break
  sleep 5
done
if [[ "$del_code" != "403" ]]; then
  fail "a DELETE from storefront to catalog-api returned $del_code, expected 403. An HTTP-method rule can only be enforced by a waypoint - ztunnel is L4 and cannot read the method, so without one the policy is accepted and does nothing"
fi

echo "PASS: ${NS} enrolled with no pod recreated, waypoint '$WP' programmed and enrolled, ${hdr}, and ${POLICY} enforced live (GET ${get_code}, DELETE ${del_code})"
exit 0
