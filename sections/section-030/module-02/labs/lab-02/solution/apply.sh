#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so students still do the work themselves.
# Kept in step with solution.md - if one changes, change the other.
set -eu

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
export PATH="$BIN_DIR:$PATH"

# 1. Move the namespace that was left behind onto the prod tag.
kubectl label namespace canary-legacy istio-injection-
kubectl label namespace canary-legacy istio.io/rev=prod --overwrite

# 2. Create its pod again so the canary control plane injects it.
kubectl -n canary-legacy rollout restart deployment tester
kubectl -n canary-legacy rollout status deployment tester --timeout=180s

# 3. Only now remove the old control plane, by its revision name. Never --purge.
istioctl uninstall --revision default -y

# Give istiod time to push the endpoints before the grader sends its request.
sleep 15
