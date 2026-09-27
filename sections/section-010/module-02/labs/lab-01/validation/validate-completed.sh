#!/usr/bin/env bash
# Confirms Istio was installed through Helm as three pinned releases, that the
# gateway is its own release in the edge namespace, that the values file reached
# the live mesh config, that no egress gateway exists, and that the pre-existing
# workload was recreated into the mesh.
#
# Every check is made with kubectl against Helm's own release Secrets and the
# resulting objects, so the grader does not depend on the helm binary.

set -u

NS="mesh-demo"
DEPLOY="notification-service"
WANT_VERSION="1.30.5"

fail() { echo "FAIL: $*"; exit 1; }

# release_status <namespace> <release-name>  ->  echoes the status of its
# newest release Secret, or nothing when no release exists.
release_status() {
  kubectl -n "$1" get secret -l "owner=helm,name=$2" \
    -o jsonpath='{range .items[*]}{.metadata.labels.version}{" "}{.metadata.labels.status}{"\n"}{end}' \
    2>/dev/null | sort -n | tail -1 | awk '{print $2}'
}

# --- 1. the three Helm releases exist and are deployed ----------------------
for entry in "istio-system istio-base" "istio-system istiod" "edge public-gateway"; do
  set -- $entry
  ns="$1"; rel="$2"
  status=$(release_status "$ns" "$rel")
  if [[ -z "$status" ]]; then
    fail "$rel - no Helm release found in namespace $ns. Install it with 'helm install $rel istio/<chart> -n $ns'"
  fi
  if [[ "$status" != "deployed" ]]; then
    fail "$rel in $ns - release status is '$status', expected 'deployed'"
  fi
done

# --- 2. the control plane is running at the pinned version ------------------
istiod_ready=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$istiod_ready" || "$istiod_ready" -lt 1 ]]; then
  fail "istiod - deployment not found in istio-system or has no ready replicas"
fi

cp_image=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
cp_version="${cp_image##*:}"
if [[ "$cp_version" != "$WANT_VERSION" ]]; then
  fail "istiod is running image '$cp_image' - expected version $WANT_VERSION. Pin the chart with --version $WANT_VERSION"
fi

# --- 3. CRDs came from the base chart ---------------------------------------
crd_count=$(kubectl get crd -o name 2>/dev/null | grep -c 'networking\.istio\.io$')
if [[ "$crd_count" -lt 1 ]]; then
  fail "no networking.istio.io CRDs found - the base chart was not installed"
fi

# --- 4. the values file reached the live mesh configuration -----------------
mesh=$(kubectl -n istio-system get configmap istio -o jsonpath='{.data.mesh}' 2>/dev/null)
if [[ -z "$mesh" ]]; then
  fail "the 'istio' ConfigMap in istio-system has no 'mesh' key"
fi
if ! grep -qE '^accessLogFile:[[:space:]]*/dev/stdout[[:space:]]*$' <<<"$mesh"; then
  fail "meshConfig.accessLogFile is not /dev/stdout in the live mesh config. Supply it through the istiod values file"
fi

autoscale=$(kubectl -n istio-system get horizontalpodautoscaler istiod \
  -o jsonpath='{.metadata.name}' 2>/dev/null)
if [[ -n "$autoscale" ]]; then
  fail "an HorizontalPodAutoscaler named istiod exists - set pilot.autoscaleEnabled to false in the values file"
fi

# --- 5. the gateway is its own release, in edge, under the right name -------
gw_ready=$(kubectl -n edge get deployment public-gateway \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$gw_ready" || "$gw_ready" -lt 1 ]]; then
  fail "public-gateway - deployment not found in namespace edge or not ready. The gateway chart names its objects after the release"
fi

if ! kubectl -n edge get service public-gateway >/dev/null 2>&1; then
  fail "public-gateway - service not found in namespace edge"
fi

gw_containers=$(kubectl -n edge get deployment public-gateway \
  -o jsonpath='{.spec.template.spec.containers[*].name}' 2>/dev/null)
if ! grep -qw "istio-proxy" <<<"$gw_containers"; then
  fail "public-gateway runs containers [$gw_containers] - expected a single istio-proxy"
fi

# --- 6. no egress gateway anywhere ------------------------------------------
egress=$(kubectl get deployments -A -o name 2>/dev/null | grep -i 'egressgateway' || true)
if [[ -n "$egress" ]]; then
  fail "an egress gateway exists ($egress) - this lab installs only an ingress gateway"
fi

# --- 7. the pre-existing workload was recreated into the mesh ---------------
injection=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ "$injection" != "enabled" ]]; then
  fail "$NS - label istio-injection is '$injection', expected 'enabled'"
fi

if ! kubectl -n "$NS" get service "$DEPLOY" >/dev/null 2>&1; then
  fail "$DEPLOY - service not found in $NS; it should have been left in place"
fi

deploy_count=$(kubectl -n "$NS" get deployments -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$deploy_count" -ne 1 ]]; then
  fail "$NS holds $deploy_count deployments, expected exactly 1 - do not add a second workload"
fi

pod=$(kubectl -n "$NS" get pod -l app="$DEPLOY" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -z "$pod" ]]; then
  fail "$DEPLOY - no running pod found in $NS"
fi

containers=$(kubectl -n "$NS" get pod "$pod" \
  -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
if ! grep -qw "istio-proxy" <<<"$containers"; then
  fail "$pod has containers [$containers] - no istio-proxy. Labelling the namespace does not inject pods that already exist; restart the workload"
fi

pod_ready=$(kubectl -n "$NS" get pod "$pod" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [[ "$pod_ready" != "True" ]]; then
  fail "$pod is not Ready"
fi

dp_image=$(kubectl -n "$NS" get pod "$pod" \
  -o jsonpath='{.spec.containers[?(@.name=="istio-proxy")].image}' 2>/dev/null)
dp_version="${dp_image##*:}"
if [[ "$cp_version" != "$dp_version" ]]; then
  fail "version skew - control plane is $cp_version, the injected proxy is $dp_version"
fi

echo "PASS: three Helm releases deployed at ${WANT_VERSION}, public-gateway running in edge, access logging live in the mesh config, no egress gateway, ${DEPLOY} recreated into the mesh"
exit 0
