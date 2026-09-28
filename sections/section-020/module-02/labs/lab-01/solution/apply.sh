#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

kubectl label namespace inject-demo istio-injection=enabled

kubectl -n inject-demo patch deployment logging-agent -p \
  '{"spec":{"template":{"metadata":{"labels":{"sidecar.istio.io/inject":"false"}}}}}'

kubectl -n inject-demo patch deployment batch-job -p \
  '{"spec":{"template":{"metadata":{"labels":{"sidecar.istio.io/inject":"true"}}}}}'

kubectl -n inject-demo rollout restart deployment notification-service
kubectl -n inject-demo rollout status deployment --timeout=180s

kubectl -n inject-demo rollout restart deployment batch-job
kubectl -n inject-demo rollout status deployment batch-job --timeout=180s

kubectl label namespace inject-demo istio-injection=enabled
kubectl -n inject-demo rollout restart deployment notification-service
kubectl -n inject-demo rollout status deployment --timeout=180s

# Give istiod time to push this configuration to every proxy before the grader
# reads it back. By hand you spend longer than this reading the apply output;
# `astrona test` applies and grades in the same second, and would otherwise
# measure the previous state.
sleep 15
