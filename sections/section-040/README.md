# Section 040: Installing Istio In Sidecar Or Ambient Mode

Welcome aboard, astronaut. In sidecar mode, every spaceship (pod) carries its own communications officer: a proxy container inside the pod. **Ambient mode** takes that officer off the ship. Shared relay towers called **ztunnel**, one on each launch pad (node), do the job for every ship docked there. The ships themselves are never changed, so a planet (namespace) joins the mesh with one label instead of a restart of every workload.

The relay towers check the envelope of each signal: who sent it and on which channel. They give the whole cluster identity and encryption (mutual TLS) at low cost. But they never open the letter. When a rule needs to read HTTP, such as a path, a method or a header, you add a **waypoint proxy**: a checkpoint station you build only where someone must read the signal's contents.

Knowing which layer owns each ability is the real subject of this section. It is what stops you debugging an `HTTPRoute` that was correct all along, with nothing in the path able to carry it out.

**Curriculum item covered:** Installing Istio in sidecar or ambient mode

---

## What You Will Master

- The parts the `ambient` profile installs next to `istiod`: `istio-cni-node` and `ztunnel`, both DaemonSets (one pod per node), and what each one does.
- Why ambient enrollment takes effect without recreating pods, and what that changes in daily work.
- Enrolling and removing a namespace with the `istio.io/dataplane-mode` label.
- Checking mesh membership with `istioctl ztunnel-config workload`, and why counting containers cannot answer that question in ambient mode.
- HBONE (HTTP-Based Overlay Network Environment), the mutual TLS tunnel between ztunnels, and reading workload identities from ztunnel's own logs.
- The boundary: what ztunnel enforces on its own at layer 4 (identities and ports), and what needs a waypoint at layer 7 (HTTP).
- What a waypoint proxy is, which object `istioctl waypoint apply` creates, and the field that makes it a waypoint instead of an ingress gateway.
- The path a request takes through a waypoint, applying a Gateway API `HTTPRoute`, and proving layer 7 processing from the response.
- Namespace waypoints versus service waypoints, and which behaviour survives when a waypoint is deleted.

---

## Modules In This Section

Work through the modules in this order. Each part teaches one idea. A mission (a graded lab) comes right after the part it practises, and the last page of each module is a wrap-up. Each module has its own playground, which you launch from the module's first page.

### [Install Istio In Ambient Mode](module-01/course.md)

2 parts and 1 mission:

1. [The Ambient Data Plane](module-01/course-01-the-ambient-data-plane.md)
2. [Enrollment, Verification And The L4 Boundary](module-01/course-02-enrollment-and-the-l4-boundary.md)
   - Mission: [Install Istio In Ambient Mode Lab](module-01/labs/lab-01/question.md)
3. [Wrap-Up: Mission Debrief](module-01/course-03-wrap-up.md)

### [Add A Waypoint Proxy For L7 In Ambient Mode](module-02/course.md)

3 parts and 1 mission:

1. [What A Waypoint Is And How Traffic Reaches It](module-02/course-01-what-a-waypoint-is.md)
2. [L7 Configuration Through A Waypoint](module-02/course-02-l7-configuration-through-a-waypoint.md)
   - Mission: [Waypoint Proxy For L7 Lab](module-02/labs/lab-01/question.md)
3. [Scoping And Removing Waypoints](module-02/course-03-scoping-and-removing-waypoints.md)
4. [Wrap-Up: Mission Debrief](module-02/course-04-wrap-up.md)

---

## Check Your Knowledge

Test your reasoning before the capstone mission:

*   **[Section 040 Knowledge Check](./quiz.md)**

---

## Capstone Mission: An Ambient Mesh With Selective L7

The capstone combines both modules in one task. You enroll a namespace with no pod recreated, add a waypoint, and enforce an HTTP-method rule that ztunnel cannot enforce on its own. You prove both outcomes with live requests: `200` for `GET` and `403` for `DELETE`.

Read the task in [`question.md`](./capstone/labs/lab-01/question.md), then start the mission:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS013.git -c sections/section-040/capstone/labs/lab-01
```

When you think you are done, send it for grading, and remove it afterwards:

```bash
astrona submit -c sections/section-040/capstone/labs/lab-01
astrona destroy ats-013-capstone-040
```
