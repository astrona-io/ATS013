#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

istioctl install -f istio-custom.yaml -y

kubectl -n payments patch deployment audit-shipper -p \
  '{"spec":{"template":{"metadata":{"labels":{"sidecar.istio.io/inject":"false"}}}}}'

kubectl label namespace payments istio-injection=enabled

kubectl -n payments rollout restart deployment checkout-api
kubectl -n payments rollout status deployment --timeout=180s

# Give istiod time to push this configuration to every proxy before the grader
# reads it back. By hand you spend longer than this reading the apply output;
# `astrona test` applies and grades in the same second, and would otherwise
# measure the previous state.
sleep 15
