#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -eu

cat > istio-custom.yaml <<'YAML'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: demo
  components:
    egressGateways:
      - name: istio-egressgateway
        enabled: false
    pilot:
      k8s:
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
  meshConfig:
    accessLogFile: /dev/stdout
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
  values:
    global:
      proxy:
        resources:
          requests:
            cpu: 20m
YAML

istioctl install -f istio-custom.yaml -y

kubectl -n payments patch deployment audit-shipper -p \
  '{"spec":{"template":{"metadata":{"labels":{"sidecar.istio.io/inject":"false"}}}}}'

kubectl label namespace payments istio-injection=enabled

# Wait until the sidecar injector is actually serving before recreating any
# workload. istioctl and helm return once the Deployments report ready, which
# is a moment before the mutating webhook can inject: a pod recreated in that
# window comes back with no istio-proxy and nothing reports an error.
wait_for_injector() {
  local i
  for i in $(seq 1 60); do
    if kubectl get mutatingwebhookconfiguration -o name 2>/dev/null | grep -q sidecar-injector; then
      if kubectl -n istio-system get endpoints -o name 2>/dev/null | grep -q istiod; then
        return 0
      fi
    fi
    sleep 2
  done
}
wait_for_injector

kubectl -n payments rollout restart deployment checkout-api
kubectl -n payments rollout status deployment --timeout=180s

# Give istiod time to push this configuration to every proxy before the grader
# reads it back. By hand you spend longer than this reading the apply output;
# `astrona test` applies and grades in the same second, and would otherwise
# measure the previous state.
sleep 15
