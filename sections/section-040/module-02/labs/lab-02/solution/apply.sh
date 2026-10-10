#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -eu

if ! command -v istioctl >/dev/null 2>&1; then
  export PATH="$HOME/.local/bin:$PATH"
fi

istioctl waypoint apply -n ambient-l7 --name svc-waypoint --for service
kubectl -n ambient-l7 rollout status deployment svc-waypoint --timeout=180s

# Point the Service at the new waypoint first, then remove the namespace-wide
# enrollment, so notification-service never loses layer 7 in between.
kubectl -n ambient-l7 label service notification-service istio.io/use-waypoint=svc-waypoint
kubectl label namespace ambient-l7 istio.io/use-waypoint-
istioctl waypoint delete waypoint -n ambient-l7

# Give istiod time to push the new routing to ztunnel before the grader reads it.
sleep 15
