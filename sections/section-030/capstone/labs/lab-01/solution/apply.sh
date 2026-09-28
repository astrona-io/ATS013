#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -euo pipefail

istioctl-1.30.5 install --set profile=minimal --set revision=1-30-5 -y

for ns in payments orders; do
  kubectl label namespace "$ns" istio.io/rev=prod --overwrite
done

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
