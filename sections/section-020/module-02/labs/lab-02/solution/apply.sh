#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -eu

kubectl -n inject-demo patch deployment notification-service -p \
  '{"spec":{"template":{"metadata":{"annotations":{"traffic.sidecar.istio.io/excludeOutboundPorts":"5432"}}}}}'
kubectl -n inject-demo rollout status deployment notification-service --timeout=180s

# Let the old pod finish terminating so the grader reads only the new one.
sleep 15
