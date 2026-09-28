#!/usr/bin/env bash
# Confirms ambient enrollment: the namespace labelled, NO pod recreated to
# achieve it (UIDs compared against the recorded baseline), no sidecars, and
# ztunnel reporting both workloads over HBONE.

set -u

NS="ambient-demo"

fail() { echo "FAIL: $*"; exit 1; }

# --- 1. the ambient data plane is still healthy -----------------------------
for ds in ztunnel istio-cni-node; do
  ready=$(kubectl -n istio-system get daemonset "$ds" \
    -o jsonpath='{.status.numberReady}' 2>/dev/null)
  if [[ -z "$ready" || "$ready" -lt 1 ]]; then
    fail "$ds - daemonset not found or has no ready pods. Ambient mode needs both istio-cni and ztunnel"
  fi
done

# --- 2. the namespace is enrolled -------------------------------------------
mode=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}' 2>/dev/null)
if [[ "$mode" != "ambient" ]]; then
  fail "$NS - label istio.io/dataplane-mode is '$mode', expected 'ambient'"
fi

# --- 3. no sidecar injection --------------------------------------------------
injection=$(kubectl get namespace "$NS" \
  -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
if [[ -n "$injection" ]]; then
  fail "$NS carries istio-injection='$injection' alongside the ambient label. A namespace is one mode or the other, never both"
fi

# --- 4. NOTHING was recreated ------------------------------------------------
baseline=$(kubectl -n "$NS" get configmap lab-baseline \
  -o jsonpath='{.data.pod-uids}' 2>/dev/null)
if [[ -z "$baseline" ]]; then
  fail "configmap $NS/lab-baseline is missing or empty - it records the pod UIDs from before enrollment and must be left in place"
fi

current=$(kubectl -n "$NS" get pods \
  -o jsonpath='{range .items[*]}{.metadata.name}={.metadata.uid}{"\n"}{end}' 2>/dev/null | sort)

if [[ "$baseline" != "$current" ]]; then
  echo "--- pods recorded before enrollment ---"
  echo "$baseline"
  echo "--- pods running now ---"
  echo "$current"
  fail "the pods are not the ones that were running before enrollment. Ambient enrollment changes node-level redirection and ztunnel's state, not the pod - so no restart is needed and none should have happened"
fi

# --- 5. still one container per pod -----------------------------------------
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

# --- 6. ztunnel actually knows about them, over HBONE -----------------------
if ! command -v istioctl >/dev/null 2>&1; then
  export PATH="$HOME/.local/bin:$PATH"
fi

zt=$(istioctl ztunnel-config workload 2>/dev/null | awk -v ns="$NS" '$1 == ns' || true)
if [[ -z "$zt" ]]; then
  fail "'istioctl ztunnel-config workload' reported nothing for $NS - is ztunnel running and the namespace enrolled?"
fi

for app in notification-service tester; do
  line=$(grep -E "[[:space:]]${app}-" <<<"$zt" | head -1)
  if [[ -z "$line" ]]; then
    fail "ztunnel does not report a workload for '$app' in $NS"
  fi
  if ! grep -qw "HBONE" <<<"$line"; then
    fail "ztunnel reports '$app' without the HBONE protocol: $line. HBONE means the workload is enrolled and reached over an mTLS tunnel; TCP means it is not in the mesh"
  fi
done

echo "PASS: ${NS} enrolled in ambient mode, every pod still the original one with a single container, and ztunnel reports both workloads over HBONE"
exit 0
