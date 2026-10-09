#!/usr/bin/env bash
# Confirms that layer 7 is scoped to one Service: a service waypoint named
# svc-waypoint serves notification-service, the namespace is no longer enrolled
# to a waypoint, the namespace waypoint is gone, and live requests show that
# only notification-service passes through a waypoint.
#
# Plausible but wrong fixes this grader rejects:
# - labelling the Service but leaving the namespace enrolled: reporting-service
#   still goes through a waypoint (ztunnel service view and server header).
# - deleting every waypoint, or the HTTPRoute: notification-service loses the
#   x-processed-by header.
# - labelling reporting-service with the service waypoint too.
# - removing the ambient label from the namespace.

set -u

NAMESPACE="ambient-l7"
SERVICE_WAYPOINT="svc-waypoint"
NAMESPACE_WAYPOINT="waypoint"
ROUTE="notification-header"
L7_SERVICE="notification-service"
L4_SERVICE="reporting-service"

fail() { echo "FAIL: $*"; exit 1; }

if ! command -v istioctl >/dev/null 2>&1; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# --- 1. still an ambient namespace ------------------------------------------
dataplane_mode=$(kubectl get namespace "$NAMESPACE" \
  -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}' 2>/dev/null)
if [[ "$dataplane_mode" != "ambient" ]]; then
  fail "$NAMESPACE - label istio.io/dataplane-mode is '$dataplane_mode', expected 'ambient'. A waypoint adds layer 7 on top of the layer 4 mesh; it does not replace it"
fi

# --- 2. the service waypoint ------------------------------------------------
gateway_class=$(kubectl -n "$NAMESPACE" get gateway "$SERVICE_WAYPOINT" \
  -o jsonpath='{.spec.gatewayClassName}' 2>/dev/null)
if [[ -z "$gateway_class" ]]; then
  fail "no Gateway named '$SERVICE_WAYPOINT' in $NAMESPACE. Create it with 'istioctl waypoint apply -n $NAMESPACE --name $SERVICE_WAYPOINT --for service'"
fi
if [[ "$gateway_class" != "istio-waypoint" ]]; then
  fail "Gateway $SERVICE_WAYPOINT has gatewayClassName '$gateway_class', expected 'istio-waypoint'"
fi

waypoint_for=$(kubectl -n "$NAMESPACE" get gateway "$SERVICE_WAYPOINT" \
  -o jsonpath='{.metadata.labels.istio\.io/waypoint-for}' 2>/dev/null)
if [[ -n "$waypoint_for" && "$waypoint_for" != "service" && "$waypoint_for" != "all" ]]; then
  fail "Gateway $SERVICE_WAYPOINT has istio.io/waypoint-for='$waypoint_for'; it must handle Service traffic (--for service)"
fi

programmed=$(kubectl -n "$NAMESPACE" get gateway "$SERVICE_WAYPOINT" \
  -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
if [[ "$programmed" != "True" ]]; then
  fail "Gateway $SERVICE_WAYPOINT reports Programmed='$programmed', expected True"
fi

ready_replicas=$(kubectl -n "$NAMESPACE" get deployment "$SERVICE_WAYPOINT" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$ready_replicas" || "$ready_replicas" -lt 1 ]]; then
  fail "the $SERVICE_WAYPOINT Deployment in $NAMESPACE is not ready"
fi

# --- 3. labels: Service in, namespace and the other Service out -------------
l7_service_label=$(kubectl -n "$NAMESPACE" get service "$L7_SERVICE" \
  -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)
if [[ "$l7_service_label" != "$SERVICE_WAYPOINT" ]]; then
  fail "Service $L7_SERVICE has istio.io/use-waypoint='$l7_service_label', expected '$SERVICE_WAYPOINT'"
fi

l4_service_label=$(kubectl -n "$NAMESPACE" get service "$L4_SERVICE" \
  -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)
if [[ -n "$l4_service_label" ]]; then
  fail "Service $L4_SERVICE has istio.io/use-waypoint='$l4_service_label'. It needs only layer 4 and must not use a waypoint"
fi

namespace_label=$(kubectl get namespace "$NAMESPACE" \
  -o jsonpath='{.metadata.labels.istio\.io/use-waypoint}' 2>/dev/null)
if [[ -n "$namespace_label" ]]; then
  fail "$NAMESPACE still has istio.io/use-waypoint='$namespace_label'. While the namespace is enrolled, every Service in it goes through a waypoint"
fi

if kubectl -n "$NAMESPACE" get gateway "$NAMESPACE_WAYPOINT" >/dev/null 2>&1; then
  fail "the namespace waypoint '$NAMESPACE_WAYPOINT' still exists in $NAMESPACE. Delete it with 'istioctl waypoint delete $NAMESPACE_WAYPOINT -n $NAMESPACE'"
fi

# --- 4. the HTTPRoute is still attached to the Service ----------------------
parent_kind=$(kubectl -n "$NAMESPACE" get httproute "$ROUTE" \
  -o jsonpath='{.spec.parentRefs[0].kind}' 2>/dev/null)
parent_name=$(kubectl -n "$NAMESPACE" get httproute "$ROUTE" \
  -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null)
if [[ "$parent_kind" != "Service" || "$parent_name" != "$L7_SERVICE" ]]; then
  fail "HTTPRoute $ROUTE is missing or attaches to '${parent_kind}/${parent_name}'; expected Service/$L7_SERVICE. Keep the route unchanged"
fi

# --- 5. ztunnel routes each Service as expected -----------------------------
# ztunnel needs a moment after a label change, so read its view a few times.
service_view_line() {
  istioctl ztunnel-config service 2>/dev/null \
    | awk -v ns="$NAMESPACE" -v name="$1" '$1 == ns && $2 == name'
}

l7_line=""
l4_line=""
for _ in 1 2 3 4 5 6; do
  l7_line=$(service_view_line "$L7_SERVICE")
  l4_line=$(service_view_line "$L4_SERVICE")
  if grep -qw "$SERVICE_WAYPOINT" <<<"$l7_line" \
     && ! grep -qE "(^|[[:space:]])($NAMESPACE_WAYPOINT|$SERVICE_WAYPOINT)([[:space:]]|$)" <<<"$l4_line"; then
    break
  fi
  sleep 5
done

if [[ -z "$l7_line" || -z "$l4_line" ]]; then
  fail "'istioctl ztunnel-config service' does not list both $L7_SERVICE and $L4_SERVICE in $NAMESPACE"
fi
if ! grep -qw "$SERVICE_WAYPOINT" <<<"$l7_line"; then
  fail "ztunnel does not route $L7_SERVICE through $SERVICE_WAYPOINT: $l7_line"
fi
if grep -qE "(^|[[:space:]])($NAMESPACE_WAYPOINT|$SERVICE_WAYPOINT)([[:space:]]|$)" <<<"$l4_line"; then
  fail "ztunnel still routes $L4_SERVICE through a waypoint: $l4_line"
fi

# --- 6. live requests: layer 7 for one Service only -------------------------
l7_response=""
for _ in 1 2 3 4 5; do
  l7_response=$(kubectl -n "$NAMESPACE" exec deploy/tester -c tester -- \
    curl -s -i -m 10 "http://$L7_SERVICE/" 2>/dev/null || true)
  grep -qi 'x-processed-by' <<<"$l7_response" && break
  sleep 5
done
if ! grep -qi '^HTTP/1.1 200' <<<"$l7_response"; then
  fail "a request from tester to $L7_SERVICE did not return 200. Response head: $(head -1 <<<"$l7_response")"
fi
if ! grep -qiE '^x-processed-by:[[:space:]]*waypoint' <<<"$(tr -d '\r' <<<"$l7_response")"; then
  fail "the response from $L7_SERVICE carries no 'x-processed-by: waypoint' header, so no waypoint processed it"
fi

l4_response=""
for _ in 1 2 3 4 5; do
  l4_response=$(kubectl -n "$NAMESPACE" exec deploy/tester -c tester -- \
    curl -s -i -m 10 "http://$L4_SERVICE/" 2>/dev/null || true)
  grep -qi '^server:[[:space:]]*istio-envoy' <<<"$l4_response" || break
  sleep 5
done
if ! grep -qi '^HTTP/1.1 200' <<<"$l4_response"; then
  fail "a request from tester to $L4_SERVICE did not return 200. Response head: $(head -1 <<<"$l4_response")"
fi
if grep -qi '^server:[[:space:]]*istio-envoy' <<<"$l4_response"; then
  fail "the response from $L4_SERVICE has 'server: istio-envoy', so it still passes through a waypoint"
fi

echo "PASS: $SERVICE_WAYPOINT serves only $L7_SERVICE (x-processed-by: waypoint), $L4_SERVICE stays on layer 4, and the namespace waypoint is gone"
exit 0
