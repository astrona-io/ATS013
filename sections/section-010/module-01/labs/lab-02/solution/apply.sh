#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -eu

istioctl uninstall --purge -y

kubectl delete namespace istio-system --ignore-not-found --wait=true --timeout=180s

kubectl label namespace mesh-demo istio-injection-

kubectl -n mesh-demo rollout restart deployment notification-service tester
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s
kubectl -n mesh-demo rollout status deployment tester --timeout=180s

# A rollout reports done while the old pods are still terminating; wait until
# no pod in mesh-demo still carries an istio-proxy container.
for attempt in $(seq 1 60); do
  if ! kubectl -n mesh-demo get pods \
      -o jsonpath='{.items[*].spec.initContainers[*].name} {.items[*].spec.containers[*].name}' \
      | grep -qw istio-proxy; then
    break
  fi
  sleep 2
done
