#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -eu

helm rollback istiod 1 -n istio-system --wait

# helm returns once istiod reports ready, a moment before the webhook can
# inject: a pod recreated in that window comes back with no istio-proxy.
wait_for_injector() {
  local attempt
  for attempt in $(seq 1 90); do
    if kubectl get mutatingwebhookconfiguration -o name 2>/dev/null | grep -q 'sidecar-injector'; then
      if kubectl -n istio-system get endpoints -o name 2>/dev/null | grep -q istiod; then
        return 0
      fi
    fi
    sleep 2
  done
}
wait_for_injector

kubectl -n default rollout restart deployment notification-service
kubectl -n default rollout status deployment notification-service --timeout=180s

# Give istiod time to settle before the grader reads the live state.
sleep 15
