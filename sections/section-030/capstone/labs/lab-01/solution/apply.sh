#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -eu

istioctl-1.30.5 install --set profile=minimal --set revision=1-30-5 -y

istioctl-1.30.5 tag set prod --revision 1-30-5 -y
istioctl-1.30.5 tag list

for ns in payments orders; do
  kubectl label namespace "$ns" istio-injection-
  kubectl label namespace "$ns" istio.io/rev=prod --overwrite
done

# The namespace is moved onto the 'prod' tag, so the webhook that must be
# serving before any pod is recreated is istio-revision-tag-prod - not the
# old default injector, which exists from the start and would make any
# weaker check pass immediately and hand the pod back to the old control plane.
wait_for_injector() {
  local i
  for i in $(seq 1 90); do
    if kubectl get mutatingwebhookconfiguration -o name 2>/dev/null | grep -q 'istio-revision-tag-prod'; then
      if kubectl -n istio-system get endpoints -o name 2>/dev/null | grep -q istiod; then
        return 0
      fi
    fi
    sleep 2
  done
}
wait_for_injector

kubectl -n payments rollout restart deployment
kubectl -n orders rollout restart deployment
kubectl -n payments rollout status deployment --timeout=300s
kubectl -n orders rollout status deployment --timeout=300s

istioctl uninstall --revision default -y

# Give istiod time to push this configuration to every proxy before the grader
# reads it back. By hand you spend longer than this reading the apply output;
# `astrona test` applies and grades in the same second, and would otherwise
# measure the previous state.
sleep 15
