#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -eu

istioctl-1.30.5 install --set profile=minimal --set revision=1-30-5 -y

istioctl-1.30.5 tag set prod --revision 1-30-5 -y
istioctl-1.30.5 tag list

kubectl label namespace canary-demo istio-injection-
kubectl label namespace canary-demo istio.io/rev=prod --overwrite

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

kubectl -n canary-demo rollout restart deployment notification-service-v1
kubectl -n canary-demo rollout status deployment notification-service-v1 --timeout=180s

# Give istiod time to push this configuration to every proxy before the grader
# reads it back. By hand you spend longer than this reading the apply output;
# `astrona test` applies and grades in the same second, and would otherwise
# measure the previous state.
sleep 15
