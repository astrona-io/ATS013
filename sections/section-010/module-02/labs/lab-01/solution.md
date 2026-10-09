# Solution Walkthrough

Mission debrief, astronaut. Follow these steps to install Istio as three Helm releases, put the gateway in its own namespace, and bring the existing workload into the mesh.

---

## Step 1: Confirm the starting state

```sh
helm ls -A
kubectl get crd | grep -c istio.io || true
```

```text
NAME    NAMESPACE   REVISION    STATUS  CHART   APP VERSION

0
```

No releases and no CRDs. Check what the chart repository offers:

```sh
helm search repo istio --versions | head -6
```

```text
NAME            CHART VERSION   APP VERSION     DESCRIPTION
istio/base      1.30.5          1.30.5          Helm chart for deploying Istio cluster resources
istio/cni       1.30.5          1.30.5          Helm chart for Istio CNI components
istio/gateway   1.30.5          1.30.5          Helm chart for deploying Istio gateways
istio/istiod    1.30.5          1.30.5          Helm chart for istio control plane
istio/ztunnel   1.30.5          1.30.5          Helm chart for Istio ztunnel components
```

`CHART VERSION` and `APP VERSION` match. That is what makes `--version 1.30.5` a real pin: that chart installs exactly that Istio.

---

## Step 2: Create the namespaces

```sh
kubectl create namespace istio-system
kubectl create namespace edge
```

```text
namespace/istio-system created
namespace/edge created
```

Neither chart creates its namespace. `--create-namespace` would also work, but on a real cluster the namespace is where labels and quotas go, so it is worth creating on its own.

The gateway lives in `edge`, not `istio-system`, on purpose. A gateway faces the internet, scales on its own and fails on its own. `istio-system` holds mission control and the cluster's certificate authority. Keeping them apart lets a team manage their gateway without access to `istio-system`.

---

## Step 3: Install `base`, the definitions

```sh
helm install istio-base istio/base -n istio-system \
  --version 1.30.5 --set defaultRevision=default --wait
```

```text
NAME: istio-base
LAST DEPLOYED: ...
NAMESPACE: istio-system
STATUS: deployed
REVISION: 1
```

Each flag has a reason:

*   `--version 1.30.5` pins the chart. Without it, Helm installs whatever is newest in the repository right now, so the same command next month gives a different Istio.
*   `--wait` makes Helm wait until the release's resources are ready, instead of returning when the API server accepts them. It stops a script racing ahead to the next chart.
*   `--set defaultRevision=default` tells the chart which control plane revision owns the injection webhook for namespaces with no revision named. Skip it on a single control plane install and injection can fail later, with no webhook willing to serve a namespace labelled `istio-injection=enabled`.

```sh
kubectl get crd | grep -c istio.io
kubectl -n istio-system get pods
```

```text
15
No resources found in istio-system namespace.
```

A deployed release, a stack of CRDs, and no pods. `base` is pure definitions. That is why installing `istiod` first fails: the kinds it needs would not exist yet, and the API server rejects them with an error that names the missing resource.

---

## Step 4: Install `istiod` from a values file

Write the file first, so the configuration is something you can commit, not a flag that lives only in your shell history.

Save this as `istiod-values.yaml`:

```yaml
meshConfig:
  accessLogFile: /dev/stdout
pilot:
  autoscaleEnabled: false
```

The two top-level keys do different jobs:

*   **`meshConfig`** is mesh-wide behaviour, the fleet's standing orders. The chart writes it word for word into a ConfigMap named `istio` in `istio-system`, under the key `mesh`. You check it there in Step 7.
*   **`pilot`** configures the control plane workload itself. `pilot` is the old name of the component that became `istiod`. With `autoscaleEnabled: false`, the chart creates no HorizontalPodAutoscaler.

Apply it:

```sh
helm install istiod istio/istiod -n istio-system \
  --version 1.30.5 -f istiod-values.yaml --wait
```

```text
NAME: istiod
STATUS: deployed
REVISION: 1
```

Then check the result:

```sh
kubectl -n istio-system get deploy istiod
```

```text
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
istiod   1/1     1            1           45s
```

---

## Step 5: Install the gateway as its own release

```sh
helm install public-gateway istio/gateway -n edge --version 1.30.5 --wait
```

```text
NAME: public-gateway
NAMESPACE: edge
STATUS: deployed
REVISION: 1
```

**The release name becomes the object name.** The chart builds the Deployment name, the Service name and the pod labels from it, so `public-gateway` gives you `deployment/public-gateway` and `service/public-gateway`. A `Gateway` resource you write later selects a gateway workload *by its labels*, so the release name matters.

```sh
kubectl -n edge get deploy,svc
kubectl -n edge get deploy public-gateway -o jsonpath='{.spec.template.spec.containers[*].name}{"\n"}'
```

```text
NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/public-gateway   1/1     1            1           30s

NAME                     TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
service/public-gateway   LoadBalancer   10.96.148.22   <pending>     15021:31...,80:31...,443:31...

istio-proxy
```

One container, `istio-proxy`: the same Envoy image a sidecar runs, deployed on its own. `EXTERNAL-IP <pending>` is expected on `kind`, which has no cloud load balancer. The Service still works through its node ports.

There is no egress gateway, and the task forbids one. The Helm path never installs a gateway you did not ask for. That is different from the `istioctl` `demo` profile, which installs both.

---

## Step 6: Bring the workload into the mesh

```sh
kubectl label namespace mesh-demo istio-injection=enabled
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
namespace/mesh-demo labeled

POD                                     CONTAINERS
notification-service-6c8f9d7b5c-t7wqx   notification-service
```

Still one container. A mutating admission webhook does the injection, and it runs only when a pod is *created*. This pod was created before the webhook applied to its namespace.

```sh
kubectl -n mesh-demo rollout restart deployment notification-service
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name'
```

```text
deployment "notification-service" successfully rolled out

POD                                     CONTAINERS
notification-service-7d4b9f6a21-k2vnm   notification-service,istio-proxy
```

This is also the real end-to-end test of the install. Three releases that say `deployed` only mean Helm applied its objects. A pod that comes back with a container you did not ask for means the CRDs, the webhook configuration and the control plane behind it all work together.

---

## Step 7: Verify

```sh
helm ls -A
```

```text
NAME             NAMESPACE      REVISION  STATUS    CHART           APP VERSION
istio-base       istio-system   1         deployed  base-1.30.5     1.30.5
istiod           istio-system   1         deployed  istiod-1.30.5   1.30.5
public-gateway   edge           1         deployed  gateway-1.30.5  1.30.5
```

```sh
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep accessLogFile
kubectl -n istio-system get hpa
```

```text
accessLogFile: /dev/stdout
No resources found in istio-system namespace.
```

The `mesh` key in the `istio` ConfigMap is the **live** mesh configuration: not what you typed, but what the cluster runs. No HorizontalPodAutoscaler confirms that `pilot.autoscaleEnabled: false` took effect.

```sh
istioctl version
istioctl proxy-status
```

```text
client version: 1.30.5
control plane version: 1.30.5
data plane version: 1.30.5 (2 proxies)
```

Two proxies: the workload's sidecar and the gateway. Here `istioctl` only reads. Running `version` or `proxy-status` against a cluster installed with Helm does not make `istioctl` an owner of the install. Only `istioctl install` and `istioctl uninstall` would.

---

## Step 8: Submit

```sh
astrona submit
```

The grader checks that:

- Helm's own release Secrets show all three releases, and each one is `deployed`.
- The `istiod` image is version `1.30.5`, and the Istio CRDs exist.
- `accessLogFile` is `/dev/stdout` in the live mesh ConfigMap, and no `istiod` HorizontalPodAutoscaler exists.
- `public-gateway` runs in `edge` with a single `istio-proxy` container, and its Service exists.
- No egress gateway exists anywhere.
- `mesh-demo` is labelled, holds one Deployment, and its pod runs `istio-proxy` on the same version as the control plane.

---

## Common mistakes

*   **Installing `istiod` before `istio-base`.** It fails with `resource mapping not found` and names a missing kind. That is the API server, not a broken chart: the CRDs are not there yet. Read the kind in the error.
*   **Using `istioctl install` because it is fewer commands.** There will be no Helm release Secrets, so the grader finds no release. It also makes two owners of the same objects, which overwrite each other.
*   **Getting the gateway release name wrong.** `helm install istio-ingressgateway istio/gateway -n edge` produces `deployment/istio-ingressgateway`, not `public-gateway`. The release name *is* the object name.
*   **Installing the gateway into `istio-system`.** The task names `edge`, and putting a workload that faces the internet next to the control plane is the habit to avoid.
*   **Passing `accessLogFile` with `--set` only.** It passes the ConfigMap check, but the task asks for a values file for a real reason: a setting that lives only inside a release is easy to lose during an upgrade.
*   **Leaving out `--version`.** The install works today but is not pinned. Two runs a month apart give two different Istio versions, and the grader checks for `1.30.5`.
*   **Forgetting the rollout restart.** The namespace label changes nothing for a pod that already exists.
