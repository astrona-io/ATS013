#!/usr/bin/env bash
# UNTESTED. Checks: pods have a sidecar, the VirtualService host exists,
# istioctl analyze is clean, and a request from tester reaches the Service.
set -u
NS="shop"
fail() { echo "FAIL: $*"; exit 1; }
if ! command -v istioctl >/dev/null 2>&1; then export PATH="$HOME/.local/bin:$PATH"; fi

ready=$(kubectl -n istio-system get deployment istiod -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ -n "$ready" && "$ready" -ge 1 ]] || fail "istiod is not ready"

for app in notification-service tester; do
  pod=$(kubectl -n "$NS" get pods -l app="$app" --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  [[ -n "$pod" ]] || fail "no running pod for $app in $NS"
  names=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}')
  grep -qw istio-proxy <<<"$names" || fail "$pod has no istio-proxy sidecar. The namespace label only affects pods created after it was set"
done

host=$(kubectl -n "$NS" get virtualservice notification-route \
  -o jsonpath='{.spec.http[0].route[0].destination.host}' 2>/dev/null)
[[ -n "$host" ]] || fail "VirtualService notification-route was deleted. Fix it instead of removing it"
[[ "$host" == "notification-service" ]] || fail "notification-route sends traffic to '$host', which is not an existing Service"

out=$(istioctl analyze -n "$NS" 2>&1 || true)
if ! grep -q "No validation issues found" <<<"$out"; then
  echo "$out"
  fail "istioctl analyze still reports issues in $NS"
fi

code=$(kubectl -n "$NS" exec deploy/tester -c tester -- curl -s -o /dev/null -w '%{http_code}' http://notification-service/ 2>/dev/null)
[[ "$code" == "200" ]] || fail "tester got HTTP '$code' from notification-service, expected 200"

echo "PASS: pods have sidecars, the route targets an existing host, analyze is clean and the request returns 200"
exit 0
