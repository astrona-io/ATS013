#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. UNTESTED.
set -eu

kubectl label namespace sidecar-shop istio-injection-
kubectl label namespace sidecar-shop istio.io/dataplane-mode=ambient
kubectl -n sidecar-shop rollout restart deployment/notification-service deployment/tester
kubectl -n sidecar-shop rollout status deployment/notification-service --timeout=300s
kubectl -n sidecar-shop rollout status deployment/tester --timeout=300s

# Give istiod time to push the change before the grader reads it back.
sleep 15
