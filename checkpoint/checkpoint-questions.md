# DevOps & GitOps Checkpoint Exam: Interview Prep & Study Guide

Use this checkpoint directory to test your knowledge, prepare for technical interviews, and consolidate your foundation in Helm, ArgoCD, and cluster operations.

---

## 🧠 Part 1: Scenario-Based Questions

### Scenario 1: The Quota Blockade
**Q**: You attempt to run `kubectl apply -f app-pod.yaml` but get the error:
`Error from server (Forbidden): pods "vitals-frontend-xxx" is forbidden: failed quota: vitals-quota: must specify limits.cpu`
What does this mean, and what is the fix?
<details>
<summary>👉 Click to reveal Answer & Explanation</summary>

* **Answer**: The namespace has a `ResourceQuota` enforced that mandates **every single container** must declare CPU and Memory requests and limits. If a pod manifest omits these parameters, the Kubernetes API Server immediately rejects it before scheduling.
* **Fix**: Update the pod's container specifications to include a `resources` block with `requests` and `limits`:
  ```yaml
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi
  ```
</details>

---

### Scenario 2: The Git HEAD Resolution Failure
**Q**: When connecting a newly initialized Git repository to ArgoCD, you see the error:
`ComparisonError: unable to resolve 'HEAD' to a commit SHA`
Why did this happen, and how do you resolve it?
<details>
<summary>👉 Click to reveal Answer & Explanation</summary>

* **Answer**: Git initializes a bare repository with the default branch set to `master`. If you pushed your local code to a branch named `main`, the remote's `HEAD` reference is still pointing to `refs/heads/master` (which does not exist on the server), making HEAD unresolvable.
* **Fix**:
  1. Update the default branch symbolic reference inside the Git server:
     `git symbolic-ref HEAD refs/heads/main`
  2. Or edit the ArgoCD Application manifest's `targetRevision` from `HEAD` to point explicitly to `main`.
</details>

---

### Scenario 3: The Flapping Autoscaler
**Q**: You deploy a Horizontal Pod Autoscaler (HPA) targeting 20% CPU utilization. You notice that the cluster replica count is constantly jumping from 2 to 5 and back to 2 every couple of minutes, causing performance instability. What is this phenomenon called, and how do you resolve it?
<details>
<summary>👉 Click to reveal Answer & Explanation</summary>

* **Answer**: This is called **Flapping** (or Thrashing). It occurs when the scaling threshold is set too close to the baseline workload. When traffic spikes slightly, HPA scales up. Because new pods share the load, average CPU instantly drops below 20%, causing HPA to scale down. As soon as pods scale down, CPU spikes again, triggering another scale-up.
* **Fix**: 
  1. Increase the CPU utilization target to a stable production threshold (typically between **50% and 70%**).
  2. Configure HPA's `behavior` block to define cooldown periods (e.g., `stabilizationWindowSeconds` during scale-down) to slow down replica deletion.
</details>

---

### Scenario 4: The Push vs. Pull Paradigm
**Q**: During a job interview, the interviewer asks: *"Why should we use ArgoCD (Pull model) instead of triggering kubectl apply from GitLab CI runners (Push model)?"* State three key security/operational arguments.
<details>
<summary>👉 Click to reveal Answer & Explanation</summary>

* **Answer**:
  1. **Credential Security**: In a push model, GitLab CI must store your cluster administrator credentials (Kubeconfig keys) to run commands. In a pull model, credentials stay inside the cluster; ArgoCD runs internally and only needs read-access to Git.
  2. **Drift Detection**: GitLab CI runs once and finishes. If a developer manually modifies a cluster resource, GitLab CI will not know. ArgoCD continuously runs a reconciliation loop, automatically correcting manual drift.
  3. **Cluster Isolation**: You do not need to open inbound port access (6443) on your Kubernetes API Server for external CI runners; the cluster can remain fully closed within a private network.
</details>

---

## 🎯 Part 2: Quick-Fire Interview Flashcards

### 1. What is the difference between a Helm Chart Version and an App Version?
> **Answer**: 
> * **Chart Version** (in `Chart.yaml`): The version of the Helm templates themselves. If you change a port variable or modify values mapping, you increment the Chart Version (e.g., `1.0.1`).
> * **App Version** (in `Chart.yaml`): The version of the actual application code inside the container (e.g. `v3.4.0` of your backend).

### 2. How does a ConfigMap differ from a Secret in Kubernetes?
> **Answer**: 
> * **ConfigMap**: Holds non-sensitive configuration data in plain text.
> * **Secret**: Holds sensitive parameters (credentials, keys) encoded in Base64 (not securely encrypted by default, but blocks plain text eyes in Git).

### 3. What does "Pruning" mean in ArgoCD?
> **Answer**: If a resource manifest is deleted from the source Git repository, ArgoCD will automatically delete (prune) that resource from the live cluster, preventing orphaned workloads.

### 4. Why does HPA require resource requests in container specifications?
> **Answer**: HPA calculates pod CPU utilization as a percentage of the pod's CPU **Request** (e.g., 20m out of a 100m request). If no request is declared, HPA has no base value to divide by, resulting in `<unknown>` utilization metrics.
