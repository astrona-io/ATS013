#!/usr/bin/env bash
# UNTESTED. Checks the sidecar-to-ambient migration of sidecar-shop.
set -u
NS="sidecar-shop"
fail() { echo "FAIL: $*"; exit 1; }
if ! command -v istioctl >/dev/null 2>&1; then export PATH="$HOME/.local/bin:$PATH"; fi

for ds in ztunnel istio-cni-node; do
  r=$(kubectl -n istio-system get daemonset "$ds" -o jsonpath='{.status.numberReady}' 2>/dev/null)
  [[ -n "$r" && "$r" -ge 1 ]] || fail "$ds has no ready pods"
done

mode=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}' 2>/dev/null)
[[ "$mode" == "ambient" ]] || fail "$NS label istio.io/dataplane-mode is '$mode', expected 'ambient'"
inj=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
[[ -z "$inj" ]] || fail "$NS still has istio-injection='$inj'. Remove it"
rev=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
[[ -z "$rev" ]] || fail "$NS still has istio.io/rev='$rev'. Remove it"

baseline=$(kubectl -n "$NS" get configmap lab-baseline -o jsonpath='{.data.pod-uids}' 2>/dev/null)
[[ -n "$baseline" ]] || fail "configmap $NS/lab-baseline is missing. Leave it in place"
current=$(kubectl -n "$NS" get pods -o jsonpath='{range .items[*]}{.metadata.name}={.metadata.uid}{"\n"}{end}' 2>/dev/null | sort)
[[ -n "$current" ]] || fail "no pods in $NS"
while read -r line; do
  [[ -n "$line" ]] || continue
  uid="${line#*=}"
  if grep -q "=${uid}\$" <<<"$baseline"; then
    fail "a pod from before the migration is still running (${line%%=*}). Create the pods again so the sidecar is removed"
  fi
done <<<"$current"

while read -r line; do
  [[ -n "$line" ]] || continue
  pod="${line%%=*}"
  names=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}')
  grep -qw istio-proxy <<<"$names" && fail "$pod still has an istio-proxy container"
done <<<"$current"

zt=$(istioctl ztunnel-config workload 2>/dev/null | awk -v ns="$NS" '$1 == ns' || true)
[[ -n "$zt" ]] || fail "ztunnel reports nothing for $NS"
for app in notification-service tester; do
  l=$(grep -E "[[:space:]]${app}-" <<<"$zt" | head -1)
  [[ -n "$l" ]] || fail "ztunnel does not report $app"
  grep -qw HBONE <<<"$l" || fail "ztunnel reports $app without HBONE: $l"
done

code=$(kubectl -n "$NS" exec deploy/tester -c tester -- curl -s -o /dev/null -w '%{http_code}' http://notification-service/ 2>/dev/null)
[[ "$code" == "200" ]] || fail "tester got HTTP '$code', expected 200"

echo "PASS: $NS runs in ambient mode, the sidecars are gone, ztunnel reports HBONE and the request returns 200"
exit 0
