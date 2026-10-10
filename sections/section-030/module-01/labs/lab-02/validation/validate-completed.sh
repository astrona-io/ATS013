#!/usr/bin/env bash
# Confirms the rollback: istiod was rolled back to revision 1 with
# `helm rollback`, every value from the original install is live again, the
# other two releases were left alone, and the workload was restarted so its
# sidecar carries the original resource requests.
#
# Plausible wrong fixes this grader rejects:
#   - "fixing forward" with a new `helm upgrade` and a rebuilt values file:
#     the end state looks the same, but the latest istiod revision is not a
#     rollback to revision 1 (its description is "Upgrade complete");
#   - rolling back and stopping: the running sidecar still has the
#     chart-default requests, because helm rollback does not restart pods.

set -u

WANT_VERSION="1.29.8"

fail() { echo "FAIL: $*"; exit 1; }

latest_revision() {
  kubectl -n "$1" get secret -l "owner=helm,name=$2" \
    -o jsonpath='{range .items[*]}{.metadata.labels.version}{"\n"}{end}' \
    2>/dev/null | sort -n | tail -1
}

revision_status() {
  kubectl -n "$1" get secret "sh.helm.release.v1.$2.v$3" \
    -o jsonpath='{.metadata.labels.status}' 2>/dev/null
}

# The release Secret holds base64( base64( gzip( JSON ) ) ). The first
# "description" field in the JSON is info.description, the text `helm history`
# prints in its DESCRIPTION column.
revision_description() {
  kubectl -n "$1" get secret "sh.helm.release.v1.$2.v$3" \
    -o jsonpath='{.data.release}' 2>/dev/null \
    | base64 --decode 2>/dev/null | base64 --decode 2>/dev/null | gzip -dc 2>/dev/null \
    | grep -o '"description":"[^"]*"' | head -1 | sed 's/^"description":"//; s/"$//'
}

# --- 1. istiod was rolled back to revision 1 with helm rollback -------------
istiod_revision=$(latest_revision istio-system istiod)
if [[ -z "$istiod_revision" ]]; then
  fail "istiod - no Helm release found in istio-system. Roll the existing release back; do not reinstall it"
fi
if [[ "$istiod_revision" -lt 3 ]]; then
  fail "istiod is still at release revision $istiod_revision - a helm rollback adds a new revision, so it should be 3 or higher"
fi
istiod_status=$(revision_status istio-system istiod "$istiod_revision")
if [[ "$istiod_status" != "deployed" ]]; then
  fail "istiod revision $istiod_revision has status '$istiod_status', expected 'deployed'"
fi
istiod_description=$(revision_description istio-system istiod "$istiod_revision")
if [[ "$istiod_description" != "Rollback to 1" ]]; then
  fail "the latest istiod revision ($istiod_revision) says '$istiod_description', expected 'Rollback to 1'. Use helm rollback to revision 1 instead of a new helm upgrade"
fi

# --- 2. the other releases were left alone ----------------------------------
for entry in "istio-system istio-base" "istio-ingress istio-ingressgateway"; do
  set -- $entry
  namespace="$1"; release="$2"
  revision=$(latest_revision "$namespace" "$release")
  if [[ "$revision" != "1" ]]; then
    fail "$release in $namespace is at revision '$revision', expected 1. Only istiod had the bad upgrade; leave the other releases alone"
  fi
done

# --- 3. the control plane is back on the original install -------------------
istiod_image=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
if [[ "${istiod_image##*:}" != "$WANT_VERSION" ]]; then
  fail "istiod is running '$istiod_image' - expected version $WANT_VERSION"
fi
istiod_ready=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -z "$istiod_ready" || "$istiod_ready" -lt 1 ]]; then
  fail "istiod - has no ready replicas after the rollback"
fi

mesh=$(kubectl -n istio-system get configmap istio -o jsonpath='{.data.mesh}' 2>/dev/null)
if [[ -z "$mesh" ]]; then
  fail "the 'istio' ConfigMap in istio-system has no 'mesh' key"
fi
if ! grep -qE '^accessLogFile:[[:space:]]*/dev/stdout[[:space:]]*$' <<<"$mesh"; then
  fail "meshConfig.accessLogFile is not /dev/stdout - the values of revision 1 are not live"
fi

if kubectl -n istio-system get horizontalpodautoscaler istiod >/dev/null 2>&1; then
  fail "an HorizontalPodAutoscaler named istiod still exists - pilot.autoscaleEnabled: false from revision 1 is not live"
fi

istiod_cpu=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
istiod_memory=$(kubectl -n istio-system get deployment istiod \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
if [[ "$istiod_cpu" != "100m" || "$istiod_memory" != "256Mi" ]]; then
  fail "istiod requests cpu='$istiod_cpu' memory='$istiod_memory', expected 100m/256Mi - the pilot.resources block of revision 1 is not live"
fi

# --- 4. the workload was restarted after the rollback -----------------------
deployment_count=$(kubectl -n default get deployment -o name 2>/dev/null | wc -l | tr -d ' ')
if [[ "$deployment_count" != "1" ]]; then
  fail "the default namespace has $deployment_count Deployments, expected only notification-service"
fi

pod=$(kubectl -n default get pod -l app=notification-service \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -z "$pod" ]]; then
  fail "notification-service - no running pod found in the default namespace"
fi
pod_ready=$(kubectl -n default get pod "$pod" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
if [[ "$pod_ready" != "True" ]]; then
  fail "$pod is not Ready"
fi

containers=$(kubectl -n default get pod "$pod" \
  -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)
if ! grep -qw "istio-proxy" <<<"$containers"; then
  fail "$pod has containers [$containers] - no istio-proxy"
fi

proxy_cpu=$(kubectl -n default get pod "$pod" \
  -o jsonpath='{.spec.initContainers[?(@.name=="istio-proxy")].resources.requests.cpu}{.spec.containers[?(@.name=="istio-proxy")].resources.requests.cpu}' 2>/dev/null)
proxy_memory=$(kubectl -n default get pod "$pod" \
  -o jsonpath='{.spec.initContainers[?(@.name=="istio-proxy")].resources.requests.memory}{.spec.containers[?(@.name=="istio-proxy")].resources.requests.memory}' 2>/dev/null)
if [[ "$proxy_cpu" != "10m" || "$proxy_memory" != "64Mi" ]]; then
  fail "the sidecar of $pod requests cpu='$proxy_cpu' memory='$proxy_memory', expected 10m/64Mi. helm rollback does not restart pods; restart the workload after the rollback"
fi

echo "PASS: istiod rolled back to revision 1 with helm rollback, every original value is live, the other releases are untouched, and the restarted sidecar has the original 10m/64Mi requests"
exit 0
