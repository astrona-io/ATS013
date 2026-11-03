# Verifying An Installation

After an install, two questions remain. Is the installation itself complete, and is the configuration on top of it correct? `istioctl` answers the first with `verify-install` and the second with `analyze`. This part uses both on the playground, where the namespace `check-demo` has two problems on purpose.

## Verify the installation itself

`istioctl verify-install` checks the cluster against the manifests the install should have created. It confirms that each expected object exists, and that each Deployment has its pods ready. Run it:

<!-- astrona:playground:renew -->

```sh
istioctl verify-install
```

On a healthy installation the command reports each object as checked and ends with a line that says the installation was verified successfully. If an object is missing or a Deployment is not ready, the command names it and exits with a non-zero code. That exit code makes the command usable in a script.

Next, check the versions of the client and the control plane, and which proxies are connected:

```sh
istioctl version
istioctl proxy-status
```

`istioctl version` prints the client version, the control plane version and the data plane versions. `istioctl proxy-status` lists every proxy that is connected to `istiod`, with one column for each type of configuration (xDS), and says whether the proxy is up to date (`SYNCED`) or not. At this point the list holds the ingress gateway only, because the application pods in `check-demo` have no sidecar.

## Analyze the configuration

`istioctl analyze` reads the live cluster, or local files, and reports configuration mistakes with a code, a severity and the object it found. Analyze the demo namespace:

```sh
istioctl analyze -n check-demo
```

Expect two messages:

- `IST0103`, level Error: a pod in a namespace with injection enabled has no sidecar. The label was added after the pods were created. Injection runs only when a pod is created, so a running pod never receives the sidecar.
- `IST0101`, level Error: the `VirtualService` `notification-route` refers to the host `notification-svc`. No Service or `ServiceEntry` with that name exists, so the route cannot work.

The message names the object and the field, so you do not have to search. To check every namespace at once, use `istioctl analyze --all-namespaces`. To check a file before you apply it, name the file: `istioctl analyze virtualservice-notification-route.yaml`.

## Fix both problems

Create the pods again so the injection webhook adds the sidecar:

```sh
kubectl -n check-demo rollout restart deployment/notification-service deployment/tester
kubectl -n check-demo rollout status deployment/tester
```

Save this as `virtualservice-notification-route.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: notification-route
  namespace: check-demo
spec:
  hosts:
    - notification-service
  http:
    - route:
        - destination:
            host: notification-service
```

Apply it:

```sh
kubectl apply -f virtualservice-notification-route.yaml
```

Then check the result:

```sh
istioctl analyze -n check-demo
istioctl proxy-status
```

The analysis now reports that it found no validation issues, and `proxy-status` lists the sidecars of both pods as well.

## Exit codes and severity

`istioctl analyze` prints messages at three levels: Error, Warning and Info. By default the command exits with the code 0 unless it found an Error. The option `--failure-threshold` changes that, so `--failure-threshold Warning` makes a warning fail the command as well. Use the option in a script that must stop on any warning.

You can now prove an installation with `verify-install`, list the connected proxies with `proxy-status`, and find the two most common configuration mistakes with `analyze`. A mesh that passes these three checks has a complete control plane, connected proxies and consistent configuration.

## Common pitfalls

> [!WARNING]
> **Labelling a namespace and expecting running pods to change.** Injection runs when a pod is created. Restart the workloads and run `istioctl analyze` to confirm.
>
> **Reading a clean `analyze` as proof that traffic works.** The analysis finds mistakes it knows about. Send a request from a pod to confirm.
>
> **Deleting the object the analysis names.** Fix the field it points at. Deleting a `VirtualService` removes the route altogether.

## Your mission: Verify A Mesh And Fix What Analyze Reports Lab

You can now run the checks that prove an installation and find configuration mistakes. The lab asks you to analyze a namespace, fix every problem the analysis reports, and prove the fix with a clean analysis and a request that returns `200`.

The lab runs on its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-013-playground-010-03
```

Then start the lab. The task is on the next page; solve it on your own first:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-010/module-03/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-03/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-013-lab-010-03
astrona start ats-013-playground-010-03
```
