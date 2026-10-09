# Welcome To The Course

This course trains you for the **Installation, Upgrade And Configuration** part of the **Istio Certified Associate (ICA)** exam. That part is 20% of the exam, and every other part of the exam assumes you can do it. This page tells you who the course is for, what you can do at the end, which words and example workloads it uses, and how its pages fit together.

## Who this course is for

You know your way around Kubernetes: namespaces, Deployments, Services, pod labels, `kubectl get`, `kubectl logs` and `kubectl exec`. You have administrator rights on a cluster, at least on your own machine. You do not need any Istio knowledge. Each new idea is explained the first time it appears.

## What you can do at the end

The exam is hands-on. You get a live cluster and a list of tasks, and you have to install, change or upgrade Istio and leave it working. So this course does not ask you to remember words. It asks you to make a change on a cluster and prove with a command that the change took effect. The exam groups this part into four topics, and each one turns into a set of skills you will practise.

The first topic is **installing Istio with `istioctl` or Helm**. You will learn to:

- Install a control plane with `istioctl install` and a profile, and print what an install would create with `istioctl manifest generate`.
- Install the same control plane with the `base`, `istiod` and `gateway` Helm charts, in the right order.
- Check which objects an install created, and remove Istio cleanly.

The second topic is **customizing the Istio installation**. You will learn to:

- Change mesh-wide settings (`meshConfig`), proxy defaults and components with an `IstioOperator` file or a Helm values file.
- Choose which namespaces and pods get a sidecar proxy, and predict the result when labels disagree.

The third topic is **upgrading Istio**. You will learn to:

- Upgrade a Helm installation without losing your values, and roll it back.
- Run a canary upgrade with revisions and revision tags, and move namespaces to the new control plane.
- Run an in-place upgrade, and bring every proxy to the new version.

The fourth topic is **installing Istio in sidecar or ambient mode**. You will learn to:

- Install ambient mode, add a namespace to the mesh without sidecars, and check it with `istioctl ztunnel-config`.
- Deploy a waypoint proxy so that layer 7 (HTTP) rules apply to ambient workloads.

Everything is built and checked on **Istio 1.30.5**. The upgrade section starts on **1.29.8** and moves to 1.30.5, so you see two versions run side by side.

## The words this course uses

The pages use Istio's, Envoy's, Helm's and Kubernetes' own terms, because those are the words you meet in the product, the logs and the exam. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

A **pod** runs one copy of an application, and a **namespace** groups pods and other objects inside the cluster. A **request** is one call that a client sends to a server, and the **response** is the answer it gets back. The **sidecar proxy** (Envoy) is a proxy container that Istio adds to each pod; all traffic in and out of the pod passes through it. **`istiod`** is Istio's control plane. It turns Istio objects and mesh settings into proxy configuration and sends it to every proxy over **xDS**, the protocol for pushing configuration to proxies while they run.

An install is described by a few more terms:

| Term | What it is |
| --- | --- |
| Profile | A built-in starting configuration for `istioctl install`, for example `default`, `demo`, `minimal` or `ambient` |
| `IstioOperator` | The YAML document `istioctl install` reads to know what to install |
| Helm release | One installed copy of a Helm chart, with a name and a numbered history |
| Revision | A named control plane, so that two versions can run side by side during an upgrade |
| Ambient mode | A way to run the mesh without sidecars, using a proxy on each node (ztunnel) and optional waypoint proxies |

## The example workloads in your playground

This course is about Istio itself, not about an application, so the workloads are small. Most playgrounds and labs run `notification-service`, an nginx Deployment behind a Service on port `80`. Where a page needs to send requests, it sends them from the `tester` pod, a client with `curl`. A few modules add small extra pods, for example `busybox` pods that only show whether they received a sidecar.

Each module uses its own namespace, for example `mesh-demo`, `inject-demo` or `canary-demo`, so the pages always tell you the namespace to use. The starting state also changes per module: some playgrounds start with no Istio at all, and the upgrade playgrounds start with an older version already installed. The landing page of each module tells you what is already there.

## How the course is laid out

The course has four sections, in the order you meet these tasks on a real cluster: first install, then customize, then upgrade, and last the choice between sidecar and ambient mode.

| Section | What it covers |
| --- | --- |
| 010 | Installing Istio With istioctl Or Helm |
| 020 | Customizing Your Istio Installation |
| 030 | Upgrading Istio (Canary, In-Place) |
| 040 | Installing Istio In Sidecar Or Ambient Mode |

Each section has two or three **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A cluster in a given starting state, a task, and a grader that checks the result | Yes |
| **Capstone** | The last lab in a section, which combines the skills of the whole section | Yes |

Each section also has a **knowledge check**, a short multiple-choice quiz before its capstone. After the last section, a closed-book **exam simulator** covers the whole domain.

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its knowledge check and capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, the real output, and then what that output shows. Run each step in your playground as you reach it. You learn more from one real result than from a page of text.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`, so you can carry on reading where you left off.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type or what you will see. Never change a command to make it "look right". If the result is different from the page, that difference is the lesson.
