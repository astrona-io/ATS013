#!/usr/bin/env bash
# Confirms the waypoint: a Gateway of class istio-waypoint, programmed and
# running, the namespace enrolled to it, ztunnel routing workloads through it,
# the HTTPRoute attached to the Service - and a live request actually carrying
# the L7 response header.

set -u

NS="ambient-l7"
WP="waypoint"
ROUTE="notification-header"

fail() { echo "FAIL: $*"; exit 1; }

if ! command -v istioctl >/dev/null 2>&1; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# --- 1. still an ambient namespace ------------------------------------------
mode=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}' 2>/dev/null)
if [[ "$mode" != "ambient" ]]; then
  fail "$NS - label istio.io/dataplane-mode is '$mode', expected 'ambient'. A waypoint adds L7 on top of the L4 mesh; it does not replace it"
fi

# --- 2. the waypoint Gateway ------------------------------------------------
class=$(kubectl -n "$NS" get gateway "$WP" \
  -o jsonpath='{.spec.gatewayClassName}' 2>/dev/null)
if [[ -z "$class" ]]; then
  fail "no Gateway named '$WP' in $NS. Create it with 'istioctl waypoint apply -n $NS --enroll-namespace'"
fi
if [[ "$class" != "istio-waypoint" ]]; then
  fail "Gateway $WP has gatewayClassName '$class', expected 'istio-waypoint'. That field is what makes it a waypoint rather than an ingress gateway"
fi

programmed=$(kubectl -n "$NS" get gateway "$WP" \
  -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
if [[ "$programmed" != "True" ]]; then
  fail "Gateway $WP reports Programmed='$programmed', expected True - Istio has not produced a running proxy for it"
fi

wp_ready=$(kubectl -n "$NS" get deployment "$WP" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$wp_ready" || "$wp_ready" -lt 1 ]]; then
  fail "the $WP deployment in $NS is not ready"
fi

# --- 3. the namespace is enrolled to it -------------------------------------
use=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)
if [[ "$use" != "$WP" ]]; then
  fail "$NS - label istio.io/use-waypoint is '$use', expected '$WP'. Creating the waypoint is not enough; the namespace must be enrolled to it (--enroll-namespace)"
fi

# --- 4. ztunnel routes the workloads through it -----------------------------
zt=$(istioctl ztunnel-config workload --namespace "$NS" 2>/dev/null || true)
if [[ -z "$zt" ]]; then
  fail "could not read 'istioctl ztunnel-config workload --namespace $NS'"
fi
app_line=$(grep -E "[[:space:]]notification-service-" <<<"$zt" | head -1)
if [[ -z "$app_line" ]]; then
  fail "ztunnel does not report a workload for notification-service in $NS"
fi
if ! grep -qw "$WP" <<<"$app_line"; then
  fail "ztunnel does not route notification-service through the waypoint: $app_line. The WAYPOINT column should name '$WP'"
fi

# --- 5. the HTTPRoute is attached to the Service ----------------------------
if ! kubectl -n "$NS" get httproute "$ROUTE" >/dev/null 2>&1; then
  fail "HTTPRoute '$ROUTE' not found in $NS"
fi

parent_kind=$(kubectl -n "$NS" get httproute "$ROUTE" \
  -o jsonpath='{.spec.parentRefs[0].kind}' 2>/dev/null)
parent_name=$(kubectl -n "$NS" get httproute "$ROUTE" \
  -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null)
if [[ "$parent_kind" != "Service" || "$parent_name" != "notification-service" ]]; then
  fail "HTTPRoute $ROUTE attaches to ${parent_kind}/${parent_name}; expected Service/notification-service. In a mesh the route attaches to the Service, not to a Gateway"
fi

accepted=$(kubectl -n "$NS" get httproute "$ROUTE" \
  -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null)
if [[ "$accepted" != "True" ]]; then
  fail "HTTPRoute $ROUTE reports Accepted='$accepted', expected True"
fi

# --- 6. the functional check: a live request carries the header -------------
# This is the only check that proves anything is parsing HTTP. Route status
# says Accepted with or without a waypoint in the path.
resp=""
for _ in 1 2 3 4 5; do
  resp=$(kubectl -n "$NS" exec deploy/tester -c tester -- \
    curl -s -i -m 10 http://notification-service/ 2>/dev/null || true)
  grep -qi 'x-processed-by' <<<"$resp" && break
  sleep 5
done

if ! grep -qi '^HTTP/1.1 200' <<<"$resp"; then
  fail "a request from tester to notification-service did not return 200. Response head: $(head -1 <<<"$resp")"
fi

hdr=$(grep -i 'x-processed-by' <<<"$resp" | tr -d '\r' || true)
if [[ -z "$hdr" ]]; then
  fail "the response carries no x-processed-by header. The HTTPRoute exists and is Accepted, but nothing in the path is parsing HTTP - check that the waypoint is running and the namespace is enrolled to it"
fi
if ! grep -qi 'x-processed-by:[[:space:]]*waypoint' <<<"$hdr"; then
  fail "the response header is '$hdr', expected 'x-processed-by: waypoint'"
fi

echo "PASS: waypoint '$WP' programmed and enrolled, ztunnel routing through it, HTTPRoute attached to the Service, and a live request returned ${hdr}"
exit 0
