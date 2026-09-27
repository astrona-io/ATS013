#!/usr/bin/env bash
# Confirms the Helm upgrade: all three releases at 1.30.5, every value from the
# original install preserved, the requested mesh change applied, and the data
# plane restarted so no version skew remains.

set -u

WANT="1.30.5"

fail() { echo "FAIL: $*"; exit 1; }

release_status() {
  kubectl -n "$1" get secret -l "owner=helm,name=$2" \
    -o jsonpath='{range .items[*]}{.metadata.labels.version}{" "}{.metadata.labels.status}{"\n"}{end}' \
    2>/dev/null | sort -n | tail -1 | awk '{print $2}'
}

release_revision() {
  kubectl -n "$1" get secret -l "owner=helm,name=$2" \
    -o jsonpath='{range .items[*]}{.metadata.labels.version}{"\n"}{end}' \
    2>/dev/null | sort -n | tail -1
}

# --- 1. all three releases still managed by Helm, and upgraded --------------
for entry in "istio-system istio-base" "istio-system istiod" "istio-ingress istio-ingressgateway"; do
  set -- $entry
  ns="$1"; rel="$2"
  status=$(release_status "$ns" "$rel")
  if [[ -z "$status" ]]; then
    fail "$rel - no Helm release found in $ns. Upgrade the existing releases; do not replace them with istioctl"
  fi
  if [[ "$status" != "deployed" ]]; then
    fail "$rel in $ns - release status is '$status', expected 'deployed'"
  fi
  rev=$(release_revision "$ns" "$rel")
  if [[ -z "$rev" || "$rev" -lt 2 ]]; then
    fail "$rel in $ns is still at release revision $rev - it was never upgraded"
  fi
done

# --- 2. control plane and gateway are on the target version -----------------
cp_image=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
cp_version="${cp_image##*:}"
if [[ "$cp_version" != "$WANT" ]]; then
  fail "istiod is running '$cp_image' - expected version $WANT"
fi

istiod_ready=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$istiod_ready" || "$istiod_ready" -lt 1 ]]; then
  fail "istiod - has no ready replicas after the upgrade"
fi

gw_image=$(kubectl -n istio-ingress get deployment istio-ingressgateway \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
gw_version="${gw_image##*:}"
if [[ -z "$gw_version" ]]; then
  fail "istio-ingressgateway - deployment not found in istio-ingress"
fi
if [[ "$gw_version" != "$WANT" ]]; then
  fail "the ingress gateway proxy is on $gw_version, expected $WANT. Gateways are workloads too - they need the helm upgrade AND a rollout restart"
fi

# --- 3. values that had to SURVIVE the upgrade ------------------------------
mesh=$(kubectl -n istio-system get configmap istio -o jsonpath='{.data.mesh}' 2>/dev/null)
if [[ -z "$mesh" ]]; then
  fail "the 'istio' ConfigMap in istio-system has no 'mesh' key"
fi
if ! grep -qE '^accessLogFile:[[:space:]]*/dev/stdout[[:space:]]*$' <<<"$mesh"; then
  fail "meshConfig.accessLogFile is no longer /dev/stdout. A bare 'helm upgrade' with no -f and no --reuse-values resets everything to chart defaults - and reports success"
fi

if kubectl -n istio-system get horizontalpodautoscaler istiod >/dev/null 2>&1; then
  fail "an HorizontalPodAutoscaler named istiod exists - pilot.autoscaleEnabled was lost in the upgrade"
fi

cpu=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
mem=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
if [[ "$cpu" != "100m" || "$mem" != "256Mi" ]]; then
  fail "istiod requests cpu='$cpu' memory='$mem', expected 100m/256Mi - the pilot.resources block from the original install was lost"
fi

# --- 4. the change that had to be APPLIED -----------------------------------
if ! grep -qE 'mode:[[:space:]]*REGISTRY_ONLY' <<<"$mesh"; then
  fail "meshConfig.outboundTrafficPolicy.mode is not REGISTRY_ONLY - the requested change was not applied"
fi

# --- 5. the data plane was restarted ----------------------------------------
pod=$(kubectl -n default get pod -l app=notification-service \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -z "$pod" ]]; then
  fail "notification-service - no running pod found in the default namespace"
fi

containers=$(kubectl -n default get pod "$pod" \
  -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
if ! grep -qw "istio-proxy" <<<"$containers"; then
  fail "$pod has containers [$containers] - no istio-proxy"
fi

dp_image=$(kubectl -n default get pod "$pod" \
  -o jsonpath='{.spec.containers[?(@.name=="istio-proxy")].image}' 2>/dev/null)
dp_version="${dp_image##*:}"
if [[ "$dp_version" != "$WANT" ]]; then
  fail "version skew - the control plane is $cp_version but the application sidecar is $dp_version. Upgrading istiod does not touch running pods; restart the workload"
fi

# --- 6. the sidecar default from the original install survived --------------
proxy_cpu=$(kubectl -n default get pod "$pod" \
  -o jsonpath='{.spec.containers[?(@.name=="istio-proxy")].resources.requests.cpu}' 2>/dev/null)
proxy_mem=$(kubectl -n default get pod "$pod" \
  -o jsonpath='{.spec.containers[?(@.name=="istio-proxy")].resources.requests.memory}' 2>/dev/null)
if [[ "$proxy_cpu" != "10m" || "$proxy_mem" != "64Mi" ]]; then
  fail "the injected sidecar requests cpu='$proxy_cpu' memory='$proxy_mem', expected 10m/64Mi - the global.proxy.resources block from the original install was lost"
fi

echo "PASS: all three releases upgraded to ${WANT}, every original value preserved, REGISTRY_ONLY applied, and the whole data plane restarted - no skew"
exit 0
