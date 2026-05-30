# GitOps Galaxy To-Do List 🌌 (Helm & GitOps)

This is your roadmap to level up from raw Kubernetes YAMLs (Cluster Chronicles) to templated, automated deployments using Helm and GitOps practices!

## Phase 1: The Helm Transition ⛵️
*Prerequisite: You should understand basic Kubernetes Deployments and Services from Cluster Chronicles before starting this phase.*

- [ ] Install Helm on your local machine.
- [ ] Understand the structure of a Helm Chart (`Chart.yaml`, `values.yaml`, `/templates`).
- [ ] Convert your raw Backend Kubernetes YAMLs into a Backend Helm Chart.
- [ ] Convert your raw Frontend Kubernetes YAMLs into a Frontend Helm Chart.
- [ ] Use `values.yaml` to make things configurable (like image tags, replica counts, and environment variables).
- [ ] Deploy your application to Minikube using your new Helm charts (`helm install`).
- [ ] Practice upgrading your release via Helm (`helm upgrade`).

## Phase 2: Introduction to GitOps (ArgoCD) 🐙
*GitOps means your Git repository is the single source of truth for your infrastructure. If it's not in Git, it shouldn't be in your cluster!*

- [ ] Research and understand the core concepts of GitOps (Declarative, Versioned, Pulled automatically, Continuously reconciled).
- [ ] Install ArgoCD onto your Minikube cluster.
- [ ] Expose the ArgoCD UI using port-forwarding or Ingress and log in.
- [ ] Install the ArgoCD CLI tool locally.

## Phase 3: Automating Deployments 🚀
- [ ] Create a dedicated Git repository (or a specific folder within your current repo) just for your Helm charts and Kubernetes manifests.
- [ ] Connect ArgoCD to your Git repository.
- [ ] Create an ArgoCD "Application" resource that points to your Frontend and Backend Helm charts in your Git repo.
- [ ] Watch ArgoCD automatically pull your charts and deploy them to your cluster!
- [ ] Test the GitOps flow: Push a change to your `values.yaml` in Git (e.g., change replica count from 2 to 3) and watch ArgoCD automatically sync the change in your cluster.

## Phase 4: Third-Party Charts 📦
*We don't need to reinvent the wheel. We can use Helm to install community-maintained software!*

- [ ] Use Helm to install the Prometheus stack (Prometheus, Grafana, Alertmanager) from the official community repository.
- [ ] Use Helm to install the EFK stack (Elasticsearch, Fluent Bit, Kibana) or Loki stack for logging.
- [ ] Have ArgoCD manage these third-party installations as well, keeping track of their `values.yaml` configurations in your Git repo.

## Phase 5: CI/CD Integration 🔄
*How does GitOps fit into CI/CD? CI builds the image, GitOps (CD) deploys it.*

- [ ] Update your existing CI pipeline (GitHub Actions or Jenkins).
- [ ] Have the CI pipeline build the new Docker image and push it to Docker Hub.
- [ ] The final step of your CI pipeline should NOT deploy to Kubernetes directly. Instead, it should automatically update the image tag in your Helm `values.yaml` file in your Git repository.
- [ ] Let ArgoCD detect the new commit in the Git repository and automatically deploy the new version.


Transitioning to GitOps: How to Study & Practice
You are exactly correct: gitops-galaxy takes the manifests from cluster-chronicles and packages them into a Helm chart (a templated package). But it adds ArgoCD (GitOps).

Instead of typing out commands like kubectl apply -f manifests/ (which is prone to manual drift and lack of audit trails), you declare the "desired state" of your cluster in a Git repository, and ArgoCD continuously reconciles the cluster to match Git.

How to Practice & Master this:
Helm Dry-Runs: Rather than trying to write complete Helm templates from memory, use helm lint and helm template locally. Running helm template outputs the raw YAML compiler results on screen so you can see exactly how variables from values.yaml replace brackets in your manifests before applying them.
Demonstrate Configuration Drift (The SRE Interview Goldmine): Once we set up ArgoCD, manually edit one of your deployments in Minikube using Lens or a kubectl edit command (e.g., change frontend replicas from 2 to 5). Then, open the ArgoCD UI dashboard and watch it flag the resource as OutOfSync and automatically revert your manual edit back to Git's state (2 replicas) in real-time. This concept is fundamental to the job.