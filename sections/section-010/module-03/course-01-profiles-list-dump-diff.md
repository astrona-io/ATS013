# Reading Profiles: list, dump and diff

Choosing a profile is the first decision of every install, and the exam often words a task by its result, such as "both gateways must run". To answer without guessing, you need to see what a profile contains. This part shows three commands that read profiles and manifests on your own machine, without changing the cluster.

## The profiles that ship with `istioctl`

A profile is a built-in `IstioOperator` document that sets defaults for the components and the values. The profiles are compiled into the `istioctl` binary, so the list depends on the version you run. Ask the binary:

<!-- astrona:playground:renew -->

```sh
istioctl profile list
```

The list includes `default`, `demo`, `minimal`, `ambient` and `empty`. The `empty` profile installs nothing and is a base for a fully hand-written configuration.

## Dumping one profile

`istioctl profile dump` prints the complete configuration of a profile as YAML. The output is long, because it holds every value the install can set. Print the whole `default` profile to a file and look at its size, then print only one branch with `--config-path`:

```sh
istioctl profile dump default > profile-default.yaml
wc -l profile-default.yaml
istioctl profile dump default --config-path components.pilot
```

The last command prints only the `pilot` component (the name `IstioOperator` uses for `istiod`). Use `--config-path` to answer a question like "what are the resource requests of `istiod` in this profile" in one command.

## Comparing two profiles

A task that says "install so that both an ingress and an egress gateway run" asks you to pick the right profile. Instead of remembering, compare:

```sh
istioctl profile diff default demo
```

The command prints the lines that differ between the two profiles. In the output of `default` against `demo`, look for the egress gateway: `demo` enables it and `default` does not. Look also for the changed resource requests and the settings that make `demo` more verbose. The output uses `-` for a line in the first profile and `+` for a line in the second.

## Rendering a manifest without applying it

`istioctl manifest generate` runs the same render step as `istioctl install`, then prints the Kubernetes manifests instead of applying them. Nothing in the cluster changes. Render the `demo` profile and count the objects by kind:

```sh
istioctl manifest generate --set profile=demo > manifest-demo.yaml
grep '^kind:' manifest-demo.yaml | sort | uniq -c
```

The second command lists each kind once with a count, so you can see the `Deployment` objects, the `Service` objects and the CRDs the profile would create.

The same command takes your overlay file. This is the safest way to check a hand-written `IstioOperator` document before you install it:

```sh
istioctl manifest generate -f istio-custom.yaml > manifest-custom.yaml
```

If the document has a mistake, such as a field `istioctl` does not know, the command fails here and nothing was applied.

## Comparing a render with the live cluster

To see what an install would change on a running cluster, pipe the render into `kubectl diff`. The command compares each rendered object with the live object and prints only the differences:

```sh
istioctl manifest generate --set profile=default | kubectl diff -f -
```

`kubectl diff` exits with the code 1 when there are differences and 0 when there are none. If the cluster was installed from the same profile and nobody edited it, the differences are small. A difference that stays tells you an object was edited by hand, and the next `istioctl install` would overwrite that edit.

You can now read what a profile holds, compare profiles, render a manifest and compare it with the cluster, all before you apply anything. The open question is what to do after the install: how to prove that the result is healthy and find mistakes in the configuration that sits on top of it.

## Common pitfalls

> [!WARNING]
> **Remembering profile contents instead of checking.** The contents change between Istio versions. Run `istioctl profile diff` with the binary you install with.
>
> **Treating `profile dump` as the live state.** It prints the profile defaults. It does not show what is installed in the cluster or what your overlay changed.
>
> **Reading `manifest generate` output as applied.** The command never writes to the cluster.
