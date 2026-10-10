#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -eu

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

helm uninstall istio-ingressgateway -n istio-ingress
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system

kubectl get crd -o name | grep 'istio.io$' | xargs -r kubectl delete
kubectl delete namespace istio-system istio-ingress --ignore-not-found

kubectl label namespace mesh-demo istio-injection-

kubectl -n mesh-demo rollout restart deployment notification-service
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s

# The old pod keeps its sidecar until it has finished terminating. Wait for it
# so the grader reads only the new pod.
sleep 15
