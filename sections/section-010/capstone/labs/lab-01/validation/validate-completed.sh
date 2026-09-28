#!/usr/bin/env bash
# Section 010 capstone grader.
#
# Confirms the whole platform specification: three pinned Helm releases, a
# NodePort gateway named public-gateway in edge, every setting from the istiod
# values file (mesh-wide AND sidecar defaults), payments fully meshed with the
# configured proxy resources, legacy deliberately left unmeshed, no egress
# gateway, and no control-plane / data-plane version skew.
#
# Every check uses kubectl against Helm's own release Secrets and the resulting
# objects, so the grader does not depend on the helm binary.

set -u

WANT_VERSION="1.30.5"

fail() { echo "FAIL: $*"; exit 1; }

release_status() {
  kubectl -n "$1" get secret -l "owner=helm,name=$2" \
    -o jsonpath='{range .items[*]}{.metadata.labels.version}{" "}{.metadata.labels.status}{"\n"}{end}' \
    2>/dev/null | sort -n | tail -1 | awk '{print $2}'
}

# --- 1. three Helm releases, deployed ---------------------------------------
for entry in "istio-system istio-base" "istio-system istiod" "edge public-gateway"; do
  set -- $entry
  ns="$1"; rel="$2"
  status=$(release_status "$ns" "$rel")
  if [[ -z "$status" ]]; then
    fail "$rel - no Helm release found in namespace $ns. This capstone must be installed with Helm, not istioctl"
  fi
  if [[ "$status" != "deployed" ]]; then
    fail "$rel in $ns - release status is '$status', expected 'deployed'"
  fi
done

# --- 2. control plane at the pinned version ---------------------------------
istiod_ready=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$istiod_ready" || "$istiod_ready" -lt 1 ]]; then
  fail "istiod - deployment not found in istio-system or has no ready replicas"
fi

cp_image=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
cp_version="${cp_image##*:}"
if [[ "$cp_version" != "$WANT_VERSION" ]]; then
  fail "istiod is running '$cp_image' - expected version $WANT_VERSION. Pin every chart with --version $WANT_VERSION"
fi

crd_count=$(kubectl get crd -o name 2>/dev/null | grep -c 'networking\.istio\.io$')
if [[ "$crd_count" -lt 1 ]]; then
  fail "no networking.istio.io CRDs found - the base chart was not installed"
fi

# --- 3. mesh-wide settings from the values file -----------------------------
mesh=$(kubectl -n istio-system get configmap istio -o jsonpath='{.data.mesh}' 2>/dev/null)
if [[ -z "$mesh" ]]; then
  fail "the 'istio' ConfigMap in istio-system has no 'mesh' key"
fi
if ! grep -qE '^accessLogFile:[[:space:]]*/dev/stdout[[:space:]]*$' <<<"$mesh"; then
  fail "meshConfig.accessLogFile is not /dev/stdout in the live mesh config"
fi
if ! grep -qE 'mode:[[:space:]]*ALLOW_ANY' <<<"$mesh"; then
  fail "meshConfig.outboundTrafficPolicy.mode is not ALLOW_ANY in the live mesh config"
fi

if kubectl -n istio-system get horizontalpodautoscaler istiod >/dev/null 2>&1; then
  fail "an HorizontalPodAutoscaler named istiod exists - set pilot.autoscaleEnabled to false"
fi

# --- 4. the gateway: name, namespace, type ----------------------------------
gw_ready=$(kubectl -n edge get deployment public-gateway \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$gw_ready" || "$gw_ready" -lt 1 ]]; then
  fail "public-gateway - deployment not found in namespace edge or not ready. The gateway chart names its objects after the release"
fi

gw_type=$(kubectl -n edge get service public-gateway \
  -o jsonpath='{.spec.type}' 2>/dev/null)
if [[ "$gw_type" != "NodePort" ]]; then
  fail "service public-gateway in edge is type '$gw_type', expected NodePort"
fi

gw_containers=$(kubectl -n edge get deployment public-gateway \
  -o jsonpath='{.spec.template.spec.containers[*].name}' 2>/dev/null)
if ! grep -qw "istio-proxy" <<<"$gw_containers"; then
  fail "public-gateway runs containers [$gw_containers] - expected a single istio-proxy"
fi

egress=$(kubectl get deployments -A -o name 2>/dev/null | grep -i 'egressgateway' || true)
if [[ -n "$egress" ]]; then
  fail "an egress gateway exists ($egress) - the specification allows only an ingress gateway"
fi

# --- 5. payments is fully meshed, with the configured proxy resources -------
injection=$(kubectl get namespace payments \
  -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ "$injection" != "enabled" ]]; then
  fail "payments - label istio-injection is '$injection', expected 'enabled'"
fi

pay_deploys=$(kubectl -n payments get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$pay_deploys" -ne 1 ]]; then
  fail "payments holds $pay_deploys deployments, expected exactly 1 - do not add workloads"
fi

if ! kubectl -n payments get service checkout-api >/dev/null 2>&1; then
  fail "checkout-api - service not found in payments; it should have been left in place"
fi

pay_pod=$(kubectl -n payments get pod -l app=checkout-api \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -z "$pay_pod" ]]; then
  fail "checkout-api - no running pod found in payments"
fi

pay_containers=$(kubectl -n payments get pod "$pay_pod" \
  -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
if ! grep -qw "istio-proxy" <<<"$pay_containers"; then
  fail "$pay_pod has containers [$pay_containers] - no istio-proxy. Labelling the namespace does not inject a pod that already exists; restart the workload"
fi

pay_ready=$(kubectl -n payments get pod "$pay_pod" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [[ "$pay_ready" != "True" ]]; then
  fail "$pay_pod is not Ready"
fi

proxy_cpu=$(kubectl -n payments get pod "$pay_pod" \
  -o jsonpath='{.spec.initContainers[?(@.name=="istio-proxy")].resources.requests.cpu}{.spec.containers[?(@.name=="istio-proxy")].resources.requests.cpu}' 2>/dev/null)
proxy_mem=$(kubectl -n payments get pod "$pay_pod" \
  -o jsonpath='{.spec.initContainers[?(@.name=="istio-proxy")].resources.requests.memory}{.spec.containers[?(@.name=="istio-proxy")].resources.requests.memory}' 2>/dev/null)
if [[ "$proxy_cpu" != "10m" ]]; then
  fail "the injected sidecar requests cpu '$proxy_cpu', expected 10m from global.proxy.resources.requests.cpu"
fi
if [[ "$proxy_mem" != "64Mi" ]]; then
  fail "the injected sidecar requests memory '$proxy_mem', expected 64Mi from global.proxy.resources.requests.memory"
fi

# --- 6. legacy is deliberately NOT meshed -----------------------------------
legacy_injection=$(kubectl get namespace legacy \
  -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ -n "$legacy_injection" ]]; then
  fail "legacy carries istio-injection='$legacy_injection' - this namespace must stay out of the mesh"
fi

legacy_rev=$(kubectl get namespace legacy \
  -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
if [[ -n "$legacy_rev" ]]; then
  fail "legacy carries istio.io/rev='$legacy_rev' - this namespace must stay out of the mesh"
fi

legacy_pod=$(kubectl -n legacy get pod -l app=batch-runner \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -z "$legacy_pod" ]]; then
  fail "batch-runner - no running pod found in legacy; it should have been left alone"
fi

legacy_containers=$(kubectl -n legacy get pod "$legacy_pod" \
  -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
if grep -qw "istio-proxy" <<<"$legacy_containers"; then
  fail "$legacy_pod has an istio-proxy sidecar - legacy must stay out of the mesh"
fi

legacy_count=$(wc -w <<<"$legacy_containers" | tr -d ' ')
if [[ "$legacy_count" -ne 1 ]]; then
  fail "$legacy_pod has $legacy_count containers [$legacy_containers], expected exactly 1"
fi

# --- 7. no version skew ------------------------------------------------------
dp_image=$(kubectl -n payments get pod "$pay_pod" \
  -o jsonpath='{.spec.initContainers[?(@.name=="istio-proxy")].image}{.spec.containers[?(@.name=="istio-proxy")].image}' 2>/dev/null)
dp_version="${dp_image##*:}"
if [[ "$cp_version" != "$dp_version" ]]; then
  fail "version skew - control plane is $cp_version, the injected proxy is $dp_version"
fi

gw_image=$(kubectl -n edge get deployment public-gateway \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
gw_version="${gw_image##*:}"
if [[ "$cp_version" != "$gw_version" ]]; then
  fail "version skew - control plane is $cp_version, the gateway proxy is $gw_version. Gateways are proxies too"
fi

echo "PASS: three Helm releases at ${WANT_VERSION}, NodePort public-gateway in edge, mesh and sidecar defaults live, payments meshed with 10m/64Mi proxy requests, legacy left out of the mesh, no egress gateway, no version skew"
exit 0
