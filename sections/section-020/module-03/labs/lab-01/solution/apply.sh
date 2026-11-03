#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. UNTESTED.
set -eu

cat > istio-gateway.yaml <<'YAML'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  components:
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
        k8s:
          resources:
            requests:
              cpu: 150m
              memory: 192Mi
          hpaSpec:
            minReplicas: 2
            maxReplicas: 4
          service:
            type: NodePort
            ports:
              - name: status-port
                port: 15021
                targetPort: 15021
              - name: http2
                port: 80
                targetPort: 8080
                nodePort: 30080
              - name: https
                port: 443
                targetPort: 8443
YAML
istioctl install -f istio-gateway.yaml -y
kubectl -n istio-system rollout status deployment/istio-ingressgateway --timeout=300s

# Give istiod time to push the change before the grader reads it back.
sleep 15
