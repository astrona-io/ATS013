#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

istioctl-1.30.5 install --set profile=default -y

kubectl -n inplace-demo rollout restart deployment
kubectl -n istio-system rollout restart deployment istio-ingressgateway
kubectl -n inplace-demo rollout status deployment --timeout=180s
kubectl -n istio-system rollout status deployment istio-ingressgateway --timeout=180s

# Give istiod time to push this configuration to every proxy before the grader
# reads it back. By hand you spend longer than this reading the apply output;
# `astrona test` applies and grades in the same second, and would otherwise
# measure the previous state.
sleep 15
