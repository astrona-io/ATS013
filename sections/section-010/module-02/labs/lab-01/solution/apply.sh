#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -eu

kubectl create namespace istio-system
kubectl create namespace edge

helm install istio-base istio/base -n istio-system \
  --version 1.30.5 --set defaultRevision=default --wait

cat > istiod-values.yaml <<'YAML'
meshConfig:
  accessLogFile: /dev/stdout
pilot:
  autoscaleEnabled: false
YAML

helm install istiod istio/istiod -n istio-system \
  --version 1.30.5 -f istiod-values.yaml --wait

helm install public-gateway istio/gateway -n edge --version 1.30.5 --wait

kubectl label namespace mesh-demo istio-injection=enabled

# Wait until the sidecar injector is actually serving before recreating any
# workload. istioctl and helm return once the Deployments report ready, which
# is a moment before the mutating webhook can inject: a pod recreated in that
# window comes back with no istio-proxy and nothing reports an error.
wait_for_injector() {
  kubectl -n istio-system rollout status deployment/istiod --timeout=300s 2>/dev/null || true
  local i
  for i in $(seq 1 60); do
    if kubectl get mutatingwebhookconfiguration -o name 2>/dev/null | grep -q sidecar-injector; then
      if kubectl -n istio-system get endpoints istiod -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | grep -q .; then
        return 0
      fi
    fi
    sleep 2
  done
}
wait_for_injector

kubectl -n mesh-demo rollout restart deployment notification-service
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s

# Give istiod time to push this configuration to every proxy before the grader
# reads it back. By hand you spend longer than this reading the apply output;
# `astrona test` applies and grades in the same second, and would otherwise
# measure the previous state.
sleep 15
