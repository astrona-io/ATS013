#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -eu

kubectl label namespace ambient-shop istio.io/dataplane-mode=ambient

istioctl waypoint apply -n ambient-shop --enroll-namespace
kubectl -n ambient-shop rollout status deployment waypoint --timeout=180s

cat > catalog-header.yaml <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: catalog-header
  namespace: ambient-shop
spec:
  parentRefs:
    - group: ""
      kind: Service
      name: catalog-api
  rules:
    - filters:
        - type: ResponseHeaderModifier
          responseHeaderModifier:
            set:
              - name: x-served-via
                value: waypoint
      backendRefs:
        - name: catalog-api
          port: 80
YAML
kubectl apply -f catalog-header.yaml

cat > catalog-methods.yaml <<'YAML'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: catalog-methods
  namespace: ambient-shop
spec:
  targetRefs:
    - group: ""
      kind: Service
      name: catalog-api
  action: ALLOW
  rules:
    - to:
        - operation:
            methods: ["GET"]
YAML
kubectl apply -f catalog-methods.yaml

# Give istiod time to push this configuration to every proxy before the grader
# reads it back. By hand you spend longer than this reading the apply output;
# `astrona test` applies and grades in the same second, and would otherwise
# measure the previous state.
sleep 15
