# GitOps Galaxy: Testing & Requirements Validation

To help you with testing and reviewing this project, I have prepared answers to the testing requirements (provided by kood/sisu), including file references and testing commands. This how-to-test.md works best combined with study-guide.md, where I explained in details with examples every concept and technology used in this project, as a way to teach myself also.

---

## Part 1: GitOps & Helm Concepts (Theoretical Rubric Answers)

### 1. How Helm Simplifies Kubernetes Application Deployments
* **Answer**: Helm simplifies Kubernetes deployments by packaging related resources (Deployments, Services, ConfigMaps, Ingress, HPA) into a single, version-controlled package called a **Chart**. It provides:
  * **Dry-Run Templating**: Compiling templates with specific values locally before applying them.
  * **Release Management**: Every install, upgrade, or rollback acts as a single versioned release transaction, allowing clean state management.
  * **Dynamic Configurations**: Replaces hardcoded values in templates with variables injected from `values.yaml` or values passed dynamically during deployment.

### 2. Why Helm Improves Productivity, Reduces Complexity, and Enhances Scalability
* **Answer**:
  * **Productivity**: Developers use pre-configured, community-maintained charts (e.g., Bitnami PostgreSQL) rather than writing complex database manifests from scratch.
  * **Complexity Reduction**: Replaces thousands of lines of duplicate YAML manifests across different namespaces (dev, staging, prod) with a single template directory and environment-specific values files.
  * **Scalability**: Updates to multi-container microservice configurations can be packaged as minor or major chart version upgrades, versioned in a chart repository.

### 3. Structure of a Helm Chart
* **Answer**:
  * `Chart.yaml`: Metadata file declaring apiVersion (`v2`), name, version, and dependency definitions.
  * `values.yaml`: Centralized configuration variables injected into template parameters.
  * `templates/`: Manifest directory holding Go template yaml files.
  * `templates/_helpers.tpl`: Named templates (macros) used to generate repeated labels or names.
  * `charts/`: Sub-directory storing required dependency charts.

### 4. How ArgoCD Implements GitOps Principles
* **Answer**: ArgoCD is a declarative, continuous delivery GitOps tool for Kubernetes. It runs inside the cluster and treats **Git as the single source of truth**:
  * It continuously monitors a registered Git repository for modifications.
  * It compares the active cluster state with the configuration defined in Git.
  * When the two states diverge, it applies the Git definition to the cluster, ensuring that the cluster always matches Git.

### 5. How ArgoCD Manages Applications (Reconciliation Loop)
* **Answer**: ArgoCD runs a continuous reconciliation loop:
  1. The **Application Controller** queries the Kubernetes API Server to pull the active state.
  2. The **Repo Server** pulls the desired state from the Git repository.
  3. If they differ, the application status transitions to `OutOfSync`.
  4. Depending on the sync policy, ArgoCD either alerts the operator or triggers automated healing to re-apply Git configurations.

### 6. Importance of Role-Based Access Control (RBAC) in Kubernetes
* **Answer**: RBAC enforces the principle of least privilege:
  * It restricts users, groups, and service accounts to only those actions (verbs) and resources they need.
  * For example, it prevents CI/CD pipelines from accessing namespaces beyond their own scope (e.g., separating the application namespace from cluster-wide system logs or secrets).

---

## Part 2: Database Deployment & Persistence (Requirements 7-9)

### 7. Database Deployment using Pre-existing Helm Chart
* **Reference**: Installed via Bitnami PostgreSQL Helm Chart in the `vitals-app` namespace.
* **Verification Command**:
  ```bash
  kubectl get pods,svc,pvc -n vitals-app -l app.kubernetes.io/name=postgresql
  ```
  *Expected Output*: Pod `vitals-db-postgresql-0` shows `Running` (1/1), Service `vitals-db-postgresql` exists, and PVC `data-vitals-db-postgresql-0` shows status `Bound`.

### 8. Database Job for Connectivity Checking
* **Reference**: Defined in [database-job.yaml]. This testing requirement is actually done during the setting up of the project, as detailed in [README.md]
* **Verification Command**:
  ```bash
  # Apply the job
  kubectl apply -f manifests/database-job.yaml

  # Check job completions
  kubectl get jobs -n vitals-app postgres-connection-check
  # Expected: COMPLETIONS 1/1

  # Review job pod logs
  kubectl logs -n vitals-app -l job-name=postgres-connection-check
  # Expected: "PostgreSQL Connection Successful! Read/Write test passed."
  ```

### 9. Database Persistence Configuration & Verification
* **Answer**: Persistence is enabled on the Bitnami chart using a PersistentVolumeClaim (configured via `--set primary.persistence.size=1Gi`).
* **Verification Procedure (Data Persistence Test)**:
  1. Log into the database and write test data:
     ```bash
     kubectl exec -it vitals-db-postgresql-0 -n vitals-app -- psql -U vitals_user -d vitals -c "CREATE TABLE test_table (id SERIAL PRIMARY KEY, val VARCHAR(50)); INSERT INTO test_table (val) VALUES ('persistence_test');"
     ```
  2. Confirm data is stored:
     ```bash
     kubectl exec -it vitals-db-postgresql-0 -n vitals-app -- psql -U vitals_user -d vitals -c "SELECT * FROM test_table;"
     ```
  3. Simulate a crash by deleting the database pod:
     ```bash
     kubectl delete pod vitals-db-postgresql-0 -n vitals-app
     ```
  4. Wait for the pod to restart and run:
     ```bash
     kubectl get pods -n vitals-app -w
     ```
  5. Once the pod is running again, verify that the data persists:
     ```bash
     kubectl exec -it vitals-db-postgresql-0 -n vitals-app -- psql -U vitals_user -d vitals -c "SELECT * FROM test_table;"
     # Expected: "persistence_test" row is returned successfully.
     ```

---

## Part 3: Custom Helm Chart Configuration (Requirements 10-16)

### 10. Custom Helm Chart Components
* **Reference**: Located in the [vitals-app] folder.
* **Structure Verification**:
  ```bash
  helm lint charts/vitals-app/
  # Expected: "0 chart(s) linted, 0 chart(s) failed"
  ```

### 11. Helm Templating System Mechanics
* **Answer**: Helm compiles Go templates (nested in the `templates/` folder) by combining them with input parameters. The syntax parses values like:
  ```yaml
  image: "{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}"
  ```
  Which translates to `vitals-backend:latest` using the default variables in `values.yaml`.

### 12. Customization via values.yaml File
* **Reference**: Declared in [values.yaml].
* **Testing Command**: Run a template compilation locally to confirm configuration changes:
  ```bash
  # Test with a modified image tag or memory limits passed dynamically
  helm template vitals-app charts/vitals-app/ --set backend.image.tag="v1.16.1" --set backend.resources.limits.memory="256Mi"
  ```
  *Verification*: Inspect the output to verify that the container image version tag and resource specifications are correctly interpolated.

### 13. Helm Rollback Functionality
* **Verification Command**:
  * Retrieve installation revisions:
    ```bash
    helm list -n vitals-app
    helm history vitals-db -n vitals-app
    ```
  * Roll back to a previous revision:
    ```bash
    helm rollback vitals-db 1 -n vitals-app
    ```
  * Or rollback the application deployment using ArgoCD's rollback function via the dashboard or CLI.

### 14. Helm Lifecycle Hooks
* **Answer**: Lifecycle hooks allow chart operations to intercept deployment steps. For example:
  * `pre-install` / `pre-upgrade`: Runs database migrations or backups before pods are updated.
  * `post-install` / `post-upgrade`: Runs logging configuration updates or checks.
  * `test`: Used to verify that the release works as expected (configured via annotations under `helm.sh/hook: test`).

### 15. Helm Dependency Management
* **Answer**: Dependencies are declared inside the `dependencies` block in `Chart.yaml`. Helm reads this list, downloads the packaged charts, and extracts them into `/charts/`.
* **Command**:
  ```bash
  helm dependency list charts/vitals-app/
  helm dependency update charts/vitals-app/
  ```

### 16. Methods for Testing Helm Charts
* **Answer**:
  1. **Linting**: Run `helm lint` to verify template syntax.
  2. **Dry-runs**: Execute `helm install --dry-run --debug` to simulate rendering.
  3. **Helm Tests**: Run test pods annotated with `helm.sh/hook: test` using `helm test <release-name>`.

---

## Part 4: ArgoCD Installation & Configuration (Requirements 17-25)

### 17. ArgoCD Installation & Access
* **Verification Command**:
  ```bash
  # Check components health
  kubectl get pods -n argocd
  # Expected: All pods (argocd-server, repo-server, application-controller) show Running.

  # Expose the dashboard interface
  kubectl port-forward service/argocd-server -n argocd 8080:443
  ```
  Open `https://localhost:8080` and log in as `admin`. Run this command to get the password:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
  ```
  

### 18. ArgoCD Control Plane Architecture
* **Answer**:
  * **API Server**: Exposes the UI, CLI, and REST API interfaces, handling authentication and user session control.
  * **Repository Server**: Clones Git repositories containing manifests and compiles Helm charts into raw Kubernetes manifests.
  * **Application Controller**: The core reconciler that continuously compares the live cluster state against the manifests generated by the Repository Server.
  * **Redis Cache**: Caches manifest rendering and cluster query data to reduce load on the API.

### 19. Git Repository Integration
* **Reference**: Configured in [argocd-app.yaml].
* **Verification**: In the ArgoCD UI under Settings -> Repositories, or CLI:
  ```bash
  kubectl get app vitals-app -n argocd -o yaml
  ```
  The repository URL is mapped to the in-cluster bare-metal Git server: `git://git-server.vitals-app.svc.cluster.local:9418/gitops-galaxy.git`.

### 20. Application Sync Tracking
* **Verification**:
  ```bash
  kubectl get applications -n argocd vitals-app
  # Expected: SYNC STATUS shows Synced, HEALTH STATUS shows Healthy.
  ```

### 21. ArgoCD Application CRD Management
* **Answer**: ArgoCD uses the `Application` custom resource to track deployments. The application manifest declares the Git source (repo, branch, folder path) and target destination (cluster endpoint, namespace), allowing the configuration to be managed as code.

### 22. ArgoCD Navigation (UI & CLI)
* **Answer**:
  * **UI**: Allows operators to review the resource dependency graph, check sync history, trigger rollbacks, and view live pod logs.
  * **CLI**: Allows developers to trigger changes directly from automation terminals:
    ```bash
    argocd app get vitals-app
    argocd app sync vitals-app
    ```

### 23. Least Privilege RBAC Configuration
* **Reference**: ArgoCD RBAC is configured via the `argocd-rbac-cm` ConfigMap in the `argocd` namespace.
* **Verification**: Review ConfigMap configurations:
  ```bash
  kubectl get configmap argocd-rbac-cm -n argocd -o yaml
  ```
  Ensure policy settings are configured to restrict write permissions for read-only user groups.

### 24. Safe Sync Options & Resource Pruning
* **Answer**:
  * `Prune=true`: Deletes resources from the cluster when they are removed from Git.
  * `CreateNamespace=true`: Automatically provisions namespaces before rendering manifests.
* **Verification**: Remove a test configmap manifest from the templates, push to Git, and verify that ArgoCD automatically prunes the configmap from the cluster during synchronization.

### 25. Configuration Drift and Self-Healing
* **Verification Procedure (SRE Drill)**:
  1. Manually scale the frontend replicas to 4:
     ```bash
     kubectl scale deployment vitals-frontend -n vitals-app --replicas=4
     ```
  2. Watch the deployment status immediately after:
     ```bash
     kubectl get deployment vitals-frontend -n vitals-app
     ```
     *Expected behavior*: Within seconds, ArgoCD flags the manual scale as drift, marks the app `OutOfSync`, and scales the replicas back down to `2` to match the configuration defined in Git.

---

## Part 5: ArgoCD Image Updater & CI/CD (Requirements 26-31)

### 26. ArgoCD Image Updater Installation
* **Verification**: Check that the controller container is operational:
  ```bash
  kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater
  ```

### 27. Git Write-Back Configuration
* **Answer**: The image updater is configured using application annotations in `argocd-app.yaml`:
  ```yaml
  argocd-image-updater.argoproj.io/write-back-method: git
  ```
  *Mechanism*: When a new container image is pushed to the registry, the Image Updater commits a file named `.argocd-source-vitals-app.yaml` back to the Git repository containing the updated tags. ArgoCD pulls this change and updates the pods automatically.

### 28. Version Constraint Filtering (Ignoring Minor & Major Updates)
* **Answer**: We enforce patch-only updates by adding SemVer constraints:
  ```yaml
  argocd-image-updater.argoproj.io/vitals-backend.update-strategy: semver
  argocd-image-updater.argoproj.io/vitals-backend.allow-tags: ~1.16.x
  ```
  *Verification*: Image tags like `1.16.1` are processed, while major updates (e.g., `2.0.0`) or minor updates (e.g., `1.17.0`) are ignored.

### 29. GitOps CI/CD Pipeline Workflow
* **Answer**:
  1. Developer commits code changes to the repository.
  2. The CI pipeline builds the Docker container and pushes it to the registry.
  3. The CI pipeline updates the image tags in the Git repository values files.
  4. ArgoCD detects the change in Git and deploys the new version to the cluster.

### 30. Pipeline Application CRD Management
* **Answer**: The CI pipeline applies the Application CRD (`manifests/argocd-app.yaml`) during bootstrap steps to register the tracking loop with the cluster API.

### 31. Pipeline Fallback & Rollback Execution
* **Verification**: If a deployment fails, we revert the last tag update commit in Git:
  ```bash
  git revert HEAD
  git push origin main
  ```
  ArgoCD detects the revert and redeploys the previous stable version.

---

## Part 6: Best Practices & Code Quality (Requirements 32-35)

### 32. Project Documentation Completeness
* **Reference**: Includes the [README.md], the incident response runbook, and the [Study Guide]

### 33. Directory Structure Standards
* **Reference**: Clear separation:
  - Application Helm Chart templates under `charts/vitals-app/`.
  - ArgoCD bootstrap resources under `manifests/`.
  - Application source files in `backend/` and `frontend/`.

### 34. Helm Formatting Best Practices
* **Reference**: Verified using `helm lint` and formatting templates with spaces rather than tabs.

### 35. Source Code Formatting Standards
* **Reference**: Backend Go code formatting checked via `go fmt ./...`.

---

## Part 7: Advanced Extra Requirements (Requirements 36-40)

### 36. Benefits of External Secret Management over Kubernetes Secrets
* **Answer**: Kubernetes Secrets are only Base64-encoded, making them vulnerable to exposure if users have read access to the namespace or etcd is unencrypted. External managers (e.g., HashiCorp Vault) store data encrypted at rest and inject secrets directly into application memory at runtime without writing them to disk.

### 37. External Secret Management Integration (HashiCorp Vault / External Secrets)
* **Answer**: External Secret Operators fetch values from Vault endpoints and map them to Kubernetes Secrets dynamically.
* **Vault Helm Annotation Injection Example**:
  ```yaml
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "vitals-app-role"
    vault.hashicorp.com/agent-inject-secret-database: "secret/data/vitals-db"
  ```

### 38. Multi-Environment CI/CD Setup
* **Answer**: We use target folders for isolated environment states:
  ```text
  environments/
  ├── dev/
  │   └── values.yaml    # Dev limits, tags, replicas
  └── prod/
      └── values.yaml    # Production limits, tags, replicas
  ```
  ArgoCD maps separate applications (`vitals-app-dev` and `vitals-app-prod`) pointing to these respective values directories.

### 39. Promotion Process Flow
* **Answer**: Code changes are merged to the `dev` branch and deployed to the staging environment. Once automated tests pass, a pull request is created to merge the changes into `main` (which represents the production state). Merging triggers ArgoCD to sync the updates to the production namespace.

### 40. Additional GitOps Features & Enhancements
* **Answer**:
  1. **In-Cluster Git Server Daemon**: Simplifies offline deployment by hosting a bare-metal Git daemon directly on Minikube's network.
  2. **Namespace Limits Config Map**: Restricts namespace resource quotas using [namespace-limits.yaml].
  3. **ArgoCD Self-Healing Configuration**: Automates drift reconciliation to instantly revert unauthorized cluster changes.
