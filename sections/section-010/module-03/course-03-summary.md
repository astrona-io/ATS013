# Summary

An installation has two parts to check: the Istio components themselves and the configuration that sits on top of them. `istioctl` reads the first before the install with profile and manifest commands, and the second after it with verification and analysis commands.

Profiles are compiled into the `istioctl` binary. `istioctl profile list` names them, `istioctl profile dump` prints the full settings of one, and `--config-path` prints only one branch. `istioctl profile diff` compares two profiles and shows, for example, that `demo` enables the egress gateway and `default` does not. These commands read only your machine, so they are safe to run at any time.

`istioctl manifest generate` runs the render step of the install and prints the manifests without applying them. It accepts the same `-f` and `--set` options as `istioctl install`, so it checks a hand-written `IstioOperator` document before you apply it. Piping the result into `kubectl diff -f -` shows what an install would change in a running cluster.

After the install, `istioctl verify-install` confirms that each expected object exists and each Deployment is ready, and it exits with a non-zero code when it is not. `istioctl version` shows the client, control plane and data plane versions, and `istioctl proxy-status` lists the proxies connected to `istiod` and whether each one is synced.

`istioctl analyze` reads the live cluster or local files and reports mistakes with codes. `IST0103` means a pod in an injection-enabled namespace has no sidecar, and the fix is to create the pod again. `IST0101` means an object refers to a resource that does not exist, and the fix is to correct the reference. A clean analysis does not prove that traffic works, so finish with a request.

Key facts to remember:

- `profile dump` and `profile diff` read profiles; they never show the live cluster.
- `manifest generate` never writes to the cluster.
- `verify-install` and `analyze` read the live cluster.
- A pod gets a sidecar only when it is created.

<!-- astrona:playground:destroy -->
