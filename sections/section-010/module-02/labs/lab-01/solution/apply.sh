#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

helm search repo istio --versions | head -6

kubectl create namespace istio-system
kubectl create namespace edge

helm install istio-base istio/base -n istio-system \
  --version 1.30.5 --set defaultRevision=default --wait

helm install istiod istio/istiod -n istio-system \
  --version 1.30.5 -f istiod-values.yaml --wait

helm install public-gateway istio/gateway -n edge --version 1.30.5 --wait

kubectl label namespace mesh-demo istio-injection=enabled

kubectl -n mesh-demo rollout restart deployment notification-service
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s

# Give istiod time to push this configuration to every proxy before the grader
# reads it back. By hand you spend longer than this reading the apply output;
# `astrona test` applies and grades in the same second, and would otherwise
# measure the previous state.
sleep 15
