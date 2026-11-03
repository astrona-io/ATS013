# Inspect Profiles And Verify An Installation

An installation is only finished when you can prove what it contains and that it is healthy. `istioctl` has commands for both. Some read the profiles and the manifests before anything is applied. Others read the live cluster after the install and report problems.

This module teaches the second half of an install: reading what a profile will create, and checking that the result is correct. These are the commands you use on the exam to confirm your work.

## Learning objectives

After this module you can:

- List the built-in profiles and print the full settings of one with `istioctl profile dump`.
- Compare two profiles with `istioctl profile diff` and say which components and values differ.
- Render the manifests of an install without applying them, with `istioctl manifest generate`.
- Check an installation with `istioctl verify-install`.
- Find configuration mistakes with `istioctl analyze`, and read the message codes `IST0101` and `IST0103`.
- Check which proxies are connected to the control plane with `istioctl proxy-status`.

## Before you start

### What you should already know

- **An `istioctl install` run.** A profile is a built-in set of defaults, and the install renders manifests and applies them.
- **Sidecar injection.** A namespace label makes the injection webhook add the `istio-proxy` container to pods when they are created.

### What is in your playground

The playground is a single-node `kind` cluster with **`istioctl` 1.30.5** and Istio installed with the `default` profile. The namespace `check-demo` holds two workloads and a `VirtualService` that has two mistakes in it. You find them with the tools in this module.

Start your playground now, and keep it running while you read the parts:

<!-- astrona:playground -->

## The parts of this module

Read the parts in this order:

1. **Reading Profiles: list, dump and diff:** how to see what a profile contains and what an install will create before you apply it.
2. **Verifying An Installation:** `verify-install`, `analyze` and `proxy-status`, and how to read their messages. The graded lab "Verify A Mesh And Fix What Analyze Reports" follows this part.

A summary closes the module.
