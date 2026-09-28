#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

kubectl create namespace istio-system
kubectl create namespace edge

helm install istio-base istio/base -n istio-system \
  --version 1.30.5 --set defaultRevision=default --wait

helm install istiod istio/istiod -n istio-system \
  --version 1.30.5 -f istiod-values.yaml --wait

helm install public-gateway istio/gateway -n edge \
  --version 1.30.5 --set service.type=NodePort --wait

kubectl label namespace payments istio-injection=enabled
kubectl -n payments rollout restart deployment checkout-api
kubectl -n payments rollout status deployment checkout-api --timeout=180s

# Give istiod time to push this configuration to every proxy before the grader
# reads it back. By hand you spend longer than this reading the apply output;
# `astrona test` applies and grades in the same second, and would otherwise
# measure the previous state.
sleep 15
