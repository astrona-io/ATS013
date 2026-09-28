#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

helm upgrade istiod istio/istiod -n istio-system --version 1.30.5 \
  -f istiod-values.yaml --dry-run --debug 2>&1 | sed -n '/COMPUTED VALUES/,/HOOKS/p' | head -20

helm upgrade istio-base istio/base -n istio-system --version 1.30.5 --wait
helm upgrade istiod istio/istiod -n istio-system --version 1.30.5 -f istiod-values.yaml --wait
helm upgrade istio-ingressgateway istio/gateway -n istio-ingress --version 1.30.5 --wait

kubectl -n default rollout restart deployment notification-service
kubectl -n istio-ingress rollout restart deployment istio-ingressgateway
kubectl -n default rollout status deployment notification-service --timeout=180s
kubectl -n istio-ingress rollout status deployment istio-ingressgateway --timeout=180s

# Give istiod time to push this configuration to every proxy before the grader
# reads it back. By hand you spend longer than this reading the apply output;
# `astrona test` applies and grades in the same second, and would otherwise
# measure the previous state.
sleep 15
