#!/usr/bin/env bash
# UNTESTED. Checks the customized ingress gateway: Service type and nodePort,
# HPA bounds, resource requests, and a request through the node port.
set -u
NS="edge-demo"
fail() { echo "FAIL: $*"; exit 1; }

ready=$(kubectl -n istio-system get deployment istio-ingressgateway -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ -n "$ready" && "$ready" -ge 1 ]] || fail "istio-ingressgateway is not ready. Keep the gateway enabled"
istiod=$(kubectl -n istio-system get deployment istiod -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[[ -n "$istiod" && "$istiod" -ge 1 ]] || fail "istiod is not ready"

type=$(kubectl -n istio-system get svc istio-ingressgateway -o jsonpath='{.spec.type}' 2>/dev/null)
[[ "$type" == "NodePort" ]] || fail "Service istio-ingressgateway has type '$type', expected NodePort"

np=$(kubectl -n istio-system get svc istio-ingressgateway -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
[[ "$np" == "30080" ]] || fail "port 80 of the gateway Service has nodePort '$np', expected 30080"

min=$(kubectl -n istio-system get hpa istio-ingressgateway -o jsonpath='{.spec.minReplicas}' 2>/dev/null)
max=$(kubectl -n istio-system get hpa istio-ingressgateway -o jsonpath='{.spec.maxReplicas}' 2>/dev/null)
[[ "$min" == "2" && "$max" == "4" ]] || fail "HorizontalPodAutoscaler istio-ingressgateway has min='$min' max='$max', expected 2 and 4"

cpu=$(kubectl -n istio-system get deployment istio-ingressgateway -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
mem=$(kubectl -n istio-system get deployment istio-ingressgateway -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
[[ "$cpu" == "150m" ]] || fail "gateway cpu request is '$cpu', expected 150m"
[[ "$mem" == "192Mi" ]] || fail "gateway memory request is '$mem', expected 192Mi"

node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
[[ -n "$node_ip" ]] || fail "could not read the node address"
code=""
for _ in 1 2 3 4 5 6; do
  code=$(kubectl -n "$NS" exec deploy/tester -- curl -s -o /dev/null -m 5 -w '%{http_code}' "http://${node_ip}:30080/" 2>/dev/null)
  [[ "$code" == "200" ]] && break
  sleep 5
done
[[ "$code" == "200" ]] || fail "a request to http://${node_ip}:30080/ returned '$code', expected 200"

echo "PASS: NodePort 30080, HPA 2 to 4, resource requests set and the route answers 200 through the node port"
exit 0
