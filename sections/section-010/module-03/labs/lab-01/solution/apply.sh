#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`. UNTESTED.
set -eu

kubectl -n shop patch virtualservice notification-route --type=json \
  -p '[{"op":"replace","path":"/spec/http/0/route/0/destination/host","value":"notification-service"}]'
kubectl -n shop rollout restart deployment/notification-service deployment/tester
kubectl -n shop rollout status deployment/notification-service --timeout=300s
kubectl -n shop rollout status deployment/tester --timeout=300s

# Give istiod time to push the change before the grader reads it back.
sleep 15
