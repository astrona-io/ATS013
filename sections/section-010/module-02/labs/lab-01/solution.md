# Solution Walkthrough

Follow these steps to install Istio as three Helm releases, put the gateway in its own namespace, and bring the existing workload into the mesh.

---

## Step 1: Confirm the starting state

```sh
helm ls -A
kubectl get crd | grep -c istio.io || true
```

```text
NAME	NAMESPACE	REVISION	UPDATED	STATUS	CHART	APP VERSION
No resources found
0
```

No releases and no CRDs (Custom Resource Definitions, which add the Istio object kinds to the API server). Check which versions the chart repository offers:

```sh
helm search repo istio --versions | head -6
```

```text
NAME               	CHART VERSION	APP VERSION	DESCRIPTION                                       
istio/istiod       	1.30.5       	1.30.5     	Helm chart for istio control plane                
istio/istiod       	1.30.4       	1.30.4     	Helm chart for istio control plane                
istio/istiod       	1.30.3       	1.30.3     	Helm chart for istio control plane                
istio/istiod       	1.30.2       	1.30.2     	Helm chart for istio control plane                
istio/istiod       	1.30.1       	1.30.1     	Helm chart for istio control plane                
```

`--versions` lists every published version of each chart, newest first, so the first rows are all versions of `istio/istiod`. `1.30.5` is there, and on every row `CHART VERSION` and `APP VERSION` match. That is what makes `--version 1.30.5` a real pin: that chart installs exactly that Istio.

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

The gateway lives in `edge`, not `istio-system`, on purpose. A gateway faces the internet, scales on its own and fails on its own. `istio-system` holds the control plane (`istiod`) and the cluster's certificate authority. Keeping them apart lets a team manage their gateway without access to `istio-system`.

---

## Step 3: Install `base`, the definitions

```sh
helm install istio-base istio/base -n istio-system \
  --version 1.30.5 --set defaultRevision=default --wait
```

The output looks like this (shortened: the release notes are left out):

```text
NAME: istio-base
LAST DEPLOYED: Sat Oct 10 01:41:44 2026
NAMESPACE: istio-system
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
```

Each flag has a reason:

*   `--version 1.30.5` pins the chart. Without it, Helm installs whatever is newest in the repository right now, so the same command next month gives a different Istio.
*   `--wait` makes Helm wait until the release's resources are ready, instead of returning when the API server accepts them. It stops a script racing ahead to the next chart.
*   `--set defaultRevision=default` tells the `base` chart which control plane revision checks Istio configuration by default. The chart creates the `istiod-default-validator` validating webhook, which sends Istio objects that carry no revision label to the `istiod` Service for a check. `default` is the chart's own default value; the flag makes it visible.

```sh
kubectl get crd | grep -c istio.io
kubectl -n istio-system get pods
```

```text
15
No resources found in istio-system namespace.
```

A deployed release, fifteen CRDs, and no pods. `base` is pure definitions. Without it, the API server rejects every Istio object you apply later, with an error that names the missing kind.

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

*   **`meshConfig`** holds mesh-wide behaviour, such as access logging. The chart writes it word for word into a ConfigMap named `istio` in `istio-system`, under the key `mesh`. You check it there in Step 7.
*   **`pilot`** configures the control plane workload itself. `pilot` is the old name of the component that became `istiod`. With `autoscaleEnabled: false`, the chart creates no HorizontalPodAutoscaler.

Apply it:

```sh
helm install istiod istio/istiod -n istio-system \
  --version 1.30.5 -f istiod-values.yaml --wait
```

The output looks like this (shortened: the release notes are left out):

```text
NAME: istiod
LAST DEPLOYED: Sat Oct 10 01:41:45 2026
NAMESPACE: istio-system
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
```

Then check the result:

```sh
kubectl -n istio-system get deploy istiod
```

```text
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
istiod   1/1     1            1           8s
```

---

## Step 5: Install the gateway as its own release

```sh
helm install public-gateway istio/gateway -n edge --version 1.30.5 --wait
```

The output looks like this (shortened: the release notes are left out):

```text
NAME: public-gateway
LAST DEPLOYED: Sat Oct 10 01:41:53 2026
NAMESPACE: edge
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
```

**The release name becomes the object name.** The chart builds the Deployment name, the Service name and the pod labels from it, so `public-gateway` gives you `deployment/public-gateway` and `service/public-gateway`. A `Gateway` resource you write later selects a gateway workload *by its labels*, so the release name matters.

```sh
kubectl -n edge get deploy,svc
kubectl -n edge get deploy public-gateway -o jsonpath='{.spec.template.spec.containers[*].name}{"\n"}'
```

```text
NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/public-gateway   1/1     1            1           7s

NAME                     TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                                      AGE
service/public-gateway   LoadBalancer   10.96.60.220   <pending>     15021:31901/TCP,80:30503/TCP,443:31459/TCP   7s
istio-proxy
```

One container, `istio-proxy`: the same Envoy image a sidecar runs, deployed on its own. `EXTERNAL-IP <pending>` is expected on `kind`, which has no cloud load balancer. The Service still works through its node ports.

There is no egress gateway, and the task forbids one. The Helm path never installs a gateway you did not ask for. That is different from the `istioctl` `demo` profile, which installs both.

---

## Step 6: Bring the workload into the mesh

```sh
kubectl label namespace mesh-demo istio-injection=enabled
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

```text
namespace/mesh-demo labeled
POD                                     INIT     CONTAINERS
notification-service-76f869bb97-sg9md   <none>   notification-service
```

Still one container and no init containers. A mutating admission webhook does the injection, and it runs only when a pod is *created*. This pod was created before the webhook applied to its namespace.

```sh
kubectl -n mesh-demo rollout restart deployment notification-service
kubectl -n mesh-demo rollout status deployment notification-service --timeout=180s
kubectl -n mesh-demo get pods -o custom-columns='POD:.metadata.name,INIT:.spec.initContainers[*].name,CONTAINERS:.spec.containers[*].name'
```

The output looks like this (shortened: the `restarted` line and the `Waiting for deployment` lines are left out):

```text
deployment "notification-service" successfully rolled out
POD                                     INIT                     CONTAINERS
notification-service-76f869bb97-sg9md   <none>                   notification-service
notification-service-86c84fbd6d-k7rpw   istio-init,istio-proxy   notification-service
```

The old pod is still shutting down; a few seconds later only the new pod is listed. The new pod has two init containers that the Deployment's template does not define. `istio-init` sets up the traffic redirection and exits. `istio-proxy` is the sidecar proxy, and it runs as a native sidecar: an init container with `restartPolicy: Always` that Kubernetes starts before the application container and keeps running beside it.

This is also the real end-to-end test of the install. Three releases that say `deployed` only mean Helm applied its objects. A pod that comes back with a container you did not ask for means the CRDs, the webhook configuration and the control plane behind it all work together.

---

## Step 7: Verify

```sh
helm ls -A
```

```text
NAME          	NAMESPACE   	REVISION	UPDATED                              	STATUS  	CHART         	APP VERSION
istio-base    	istio-system	1       	2026-10-10 01:41:44.312113 +0200 CEST	deployed	base-1.30.5   	1.30.5     
istiod        	istio-system	1       	2026-10-10 01:41:45.044384 +0200 CEST	deployed	istiod-1.30.5 	1.30.5     
public-gateway	edge        	1       	2026-10-10 01:41:53.24164 +0200 CEST 	deployed	gateway-1.30.5	1.30.5     
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
NAME                                                CLUSTER        ISTIOD                     VERSION     SUBSCRIBED TYPES
notification-service-86c84fbd6d-k7rpw.mesh-demo     Kubernetes     istiod-995fd9df6-52jcs     1.30.5      4 (CDS,LDS,EDS,RDS)
public-gateway-79c878878f-4mhr2.edge                Kubernetes     istiod-995fd9df6-52jcs     1.30.5      3 (CDS,LDS,EDS)
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

*   **Installing `istiod` before `istio-base`.** Helm reports the `istiod` release as `deployed`, because the chart holds only built-in kinds. The failure comes later: every Istio object you apply fails with `resource mapping not found` and names a missing kind. That is the API server, not a broken file: the CRDs are not there yet. Read the kind in the error.
*   **Using `istioctl install` because it is fewer commands.** There will be no Helm release Secrets, so the grader finds no release. It also makes two owners of the same objects, which overwrite each other.
*   **Getting the gateway release name wrong.** `helm install istio-ingressgateway istio/gateway -n edge` produces `deployment/istio-ingressgateway`, not `public-gateway`. The release name *is* the object name.
*   **Installing the gateway into `istio-system`.** The task names `edge`, and putting a workload that faces the internet next to the control plane is the habit to avoid.
*   **Passing `accessLogFile` with `--set` only.** It passes the ConfigMap check, but the task asks for a values file for a real reason: a setting that lives only inside a release is easy to lose during an upgrade.
*   **Leaving out `--version`.** The install works today but is not pinned. Two runs a month apart give two different Istio versions, and the grader checks for `1.30.5`.
*   **Forgetting the rollout restart.** The namespace label changes nothing for a pod that already exists.
