# Summary

A canary upgrade installs a second Istio control plane next to the running one, moves workloads onto it one namespace at a time, and removes the old control plane only at the end. It works because a revision is a named, independent copy of the control plane. `istioctl install --set profile=minimal --set revision=1-30-5` creates `istiod-1-30-5`, its own Service and its own injection webhook, `istio-sidecar-injector-1-30-5`, next to the objects of the default revision, which have no suffix. Each install only manages objects with its own `istio.io/rev` ownership label, so one revision never prunes the other. The CRDs (Custom Resource Definitions) are shared by every revision. Revision names become parts of object names, so they must be valid DNS labels: `1-30-5`, never `1.30.5`.

Installing a revision moves nothing. Injection happens only when a pod is created, so running pods stay connected to the control plane that injected them. `istioctl proxy-status` asks one control plane, the default revision unless you pass `--revision`, and its `ISTIOD` column names the `istiod` pod each proxy is connected to, and the proxy image of a pod shows the version it runs. The canary uses the `minimal` profile because it needs a second control plane, not a second set of gateways.

A namespace picks its control plane with a label. `istio-injection=enabled` selects the default revision, and `istio.io/rev=<name>` selects a named revision or tag. The webhook of a revision requires `istio-injection` to be absent, so when both labels are present, `istio-injection` wins and nothing warns you. A move therefore takes three steps: remove `istio-injection`, set `istio.io/rev`, and restart the workload. Only the restart moves the workload, and a rollback is the same three steps in reverse.

A revision tag, such as `prod`, is a mutating webhook configuration, `istio-revision-tag-prod`, that sends injection requests to the `istiod` Service of one revision. Namespaces labelled `istio.io/rev=prod` follow the tag, so an upgrade or a rollback is one `istioctl tag set prod --revision <name> --overwrite -y` plus restarts, and no namespace label changes. `istioctl tag list` shows where each tag points and which namespaces follow it.

The old revision goes last. First prove that plain `istioctl proxy-status`, which asks the old default revision, lists no workload any more, and that no namespace is still labelled for the old one, then run `istioctl uninstall --revision default -y`. Pods left on a removed control plane keep running but get no configuration updates and no certificate renewal, so they fail hours later. `--purge` removes every revision and the shared CRDs, so it is the wrong command during a canary upgrade. Gateways are standalone Deployments and move as their own step.

Key facts to remember:

- Revision names are DNS labels: dashes, no dots.
- With both namespace labels present, `istio-injection` wins.
- Nothing moves until a pod is created again.
- Restart every workload first, then uninstall the old revision by name.

<!-- astrona:playground:destroy -->
